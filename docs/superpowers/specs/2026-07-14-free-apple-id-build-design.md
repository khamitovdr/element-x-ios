# Building the fork with a free Apple ID

**Date:** 2026-07-14
**Status:** Approved

## Problem

This fork is developed on a free Apple ID (a "Personal Team"), with no paid Apple
Developer Program enrollment. Four of the entitlements Element X declares are
available only to paid members, so the project cannot be signed or installed on a
physical device as it stands:

| Entitlement | Declared by |
|---|---|
| `aps-environment` (push) | ElementX |
| `com.apple.developer.associated-domains` | ElementX |
| `com.apple.developer.usernotifications.communication` | ElementX |
| `com.apple.security.application-groups` | ElementX, NSE, ShareExtension |

The build must work on both the Simulator (UI work) and a physical iPhone (round
video message recording needs a real camera).

The fork tracks `upstream/develop` and must stay mergeable with it. If the app is
ever published, every concession made here must be quick and obvious to undo.

## Goals

- The project builds, installs, and runs on a device signed by a Personal Team.
- Every disabled feature is discoverable in-file, not just in git history.
- Reverting to a publishable configuration is mechanical.
- The diff against upstream is small and confined to build configuration.

## Non-goals

- Push notifications, the share sheet, and universal links. All require a paid
  account; none are needed to develop round video messages.
- Any change to application source code. This is a build-configuration change only.

## Key findings

Three facts from the codebase determine the design.

**Entitlements are generated, not authored.** The `.entitlements` files under each
target's `SupportingFiles/` are emitted by XcodeGen from the `entitlements:
properties:` blocks in the corresponding `target.yml`. Editing an `.entitlements`
file directly has no effect — the next `xcodegen` run overwrites it. All edits go
in the yml.

**Losing the App Group container is already handled.** `URL.appGroupContainerDirectory`
(`ElementX/Sources/Other/Extensions/URL.swift:15-26`) falls back to the app's own
sandbox container when `containerURL(forSecurityApplicationGroupIdentifier:)`
returns nil, logging `Application Group unavailable, falling back to the
application folder`. The fallback exists for BrowserStack resigning, but a free
account is in exactly the same position. Sessions, logs, caches, and `UserDefaults`
therefore keep working for the main app. The *shared* container only matters for
passing data between the app and its extensions.

**The app target already compiles the NSE's source.** `ElementX/SupportingFiles/target.yml:282`
lists `../../NSE/Sources` among the app target's `sources`, with a comment
explaining it is done so unit tests can link NSE code. Removing the NSE **target**
therefore stops the `.appex` being built and embedded, but leaves the NSE code
compiling into the app and the tests linking. No other yml depends on the NSE or
ShareExtension targets, and no scheme references them (XcodeGen generates schemes
per target).

## Rejected approach: the variant override hook

`project.yml:71` carries a commented-out `# - path: MyAppVariant/override.yml`, and
`Variants/Nightly/nightly.yml` is a working example of the mechanism: a yml appended
to the `include:` list whose values are merged over the base.

This cannot do the job. XcodeGen merges includes **additively**. An override can
*change* a value — which is all Nightly does; it overrides scalars like
`APP_GROUP_IDENTIFIER` — but it cannot **delete** an entitlement key or **remove** a
target. Stripping `aps-environment` and App Groups requires editing the source yml.

## Design

### Marker convention

No paid-only line is deleted. Each is commented out and tagged:

```yaml
# FREE-ACCOUNT: requires a paid Apple Developer Program membership.
# aps-environment: development
```

`grep -rn "FREE-ACCOUNT" .` then yields the complete, exhaustive list of everything
that must be restored to publish. The disabled lines stay next to the code they
belong to, so the configuration explains itself without reference to git.

### File changes

**`app.yml`** — three settings become fork-specific:

- `BASE_BUNDLE_IDENTIFIER`: `io.element.elementx` → `com.khamitovdr.elementx`.
  Element's identifier cannot be claimed by another team.
- `DEVELOPMENT_TEAM`: `7J4U792NQT` → the Personal Team ID, read from the Apple
  Development certificate once the prerequisite below is done.
- `APP_GROUP_IDENTIFIER`: **unchanged.** With the entitlement gone the value is
  inert; the code takes the fallback path above. Leaving it minimises the diff.

**`ElementX/SupportingFiles/target.yml`** — in `entitlements: properties:` (lines
113-134), comment out with the marker:

- `aps-environment`
- `com.apple.developer.associated-domains` and its seven domain entries
- `com.apple.developer.usernotifications.communication`
- `com.apple.security.application-groups` and both of its entries

Retained: `com.apple.security.app-sandbox`, `com.apple.security.network.client`, and
`keychain-access-groups`.

In `dependencies` (lines 227-229), comment out with the marker:

- `- target: NSE`
- `- target: ShareExtension`

**`project.yml`** — in `include:` (lines 63-64), comment out with the marker:

- `- path: NSE/SupportingFiles/target.yml`
- `- path: ShareExtension/SupportingFiles/target.yml`

**`NSE/SupportingFiles/target.yml` and `ShareExtension/SupportingFiles/target.yml`** —
untouched. Once un-included they are inert files; there is nothing to strip and
nothing to restore.

### Keychain Sharing is deliberately retained

`keychain-access-groups` is kept. Keychain Sharing is available to Personal Teams,
and `KeychainController` passes an access group when reading and writing
credentials; removing the entitlement while leaving the access group in the code
would fail at runtime with `errSecMissingEntitlement` (`-34018`).

This is a judged bet, not a certainty. If device signing rejects the entitlement,
the fallback is to strip it *and* remove the access group from `KeychainController`
— a source change, and therefore a decision to bring back to the author rather than
make silently.

### Git shape

The change lands on a `free-apple-id-build` branch cut from `develop`, and is merged
into the **fork's own** `develop` by pull request. The feature branch
`round-video-messages` is then rebased onto the updated `develop`, so the build
configuration sits beneath the feature work rather than tangled through it.

The branch carries one commit per concern (entitlements, extension targets, fork
identity) rather than a single squashed commit, matching this repo's convention of
"no tiny commits, no massive commits".

Two properties this preserves:

- Upstream merges conflict only in the three yml files, each with small hunks.
- Publishing means reverting a short, clearly-titled run of commits — or simply
  following the `FREE-ACCOUNT` markers, which is the primary undo path.

The pull request must target `khamitovdr/element-x-ios`, **never** `element-hq/element-x-ios`.
`gh pr create` defaults its base to the upstream parent of a fork, so every invocation
must pass `--repo khamitovdr/element-x-ios` explicitly. This configuration is
fork-local and must never be proposed to the upstream project.

## Prerequisite

The development machine currently has **no code-signing identities**
(`security find-identity -v -p codesigning` reports `0 valid identities found`), so
no Personal Team exists yet and its ID cannot be read.

Before the device build can be configured, the author must add their Apple ID in
**Xcode → Settings → Accounts**. That creates the Personal Team and an Apple
Development certificate, from which the team ID can be read and written into
`app.yml`.

Simulator builds do not enforce code signing and are unblocked without this step.

## Verification

1. `xcodegen` regenerates the project without error.
2. The ElementX scheme builds for the Simulator.
3. The ElementX scheme builds, signs, and installs on a physical iPhone.
4. The app launches and logs `Application Group unavailable, falling back to the
   application folder`.
5. Password login against the author's self-hosted Synapse succeeds. (That server
   configures no `oidc_providers`, no MAS, and no MSC3861, so Element X uses the
   password flow and never exercises the HTTPS OAuth callback that the
   associated-domains entitlement underwrites.)
6. `grep -rn "FREE-ACCOUNT" .` lists every disabled line and nothing else.

## Accepted risks

**Seven-day provisioning expiry.** Free-account provisioning profiles expire after
seven days, after which the installed app refuses to launch until rebuilt from
Xcode. This is an Apple constraint that no project configuration can avoid.

**Keychain Sharing.** As above: retained on a judgement call, with a known fallback
that requires a source change.

**Share sheet and push are gone.** Accepted; neither is needed for the feature work.
