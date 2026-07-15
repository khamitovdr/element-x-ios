# Neutrino branding — design

Give the fork its own identity: app name **Neutrino** and a custom app
icon (light / dark / tinted). Purely cosmetic — no change to bundle ID,
target/product name, signing, or behaviour, so the existing install keeps
its session and data.

## Name

Two `app.yml` settings drive every user-visible name; both become `Neutrino`:

| Setting | Was | Now | Where it shows |
|---|---|---|---|
| `APP_DISPLAY_NAME` | `Element X` | `Neutrino` | `CFBundleDisplayName` → home-screen name; and in-app everywhere via `InfoPlistReader.bundleDisplayName` (user-agent, login device name, invite text, permission dialogs, app-lock, key-backup copy…) |
| `PRODUCTION_APP_NAME` | `Element` | `Neutrino` | `productionAppName` → onboarding welcome ("Welcome to Neutrino"), encryption-reset / secure-backup copy |

No source strings are touched — every consumer already reads these
Info.plist values indirectly, so the two-line settings change propagates
throughout. `en`/`Localizable.strings` untouched (auto-managed).

**Explicitly unchanged:** `BASE_BUNDLE_IDENTIFIER` (`com.khamitovdr.elementx`)
and the internal `ElementX` target/product/scheme name.

## Icon

Source assets: three flat 1024×1024 opaque PNGs in `~/Downloads/icons/`
(`icon-light-1024.png`, `icon-dark-1024.png`, `icon-tinted-1024.png`) —
exactly the iOS 18 light / dark / tinted appearance model.

Current icon is a single-layer Icon Composer bundle
(`ElementX/Resources/AppIcon.icon`). That format is designed to *derive*
dark/tinted from one artwork, not host three distinct flat images, so we
replace it with a classic appearance-aware asset:

- **Remove** `ElementX/Resources/AppIcon.icon/`.
- **Add** `ElementX/Resources/Assets.xcassets/AppIcon.appiconset/` with the
  three PNGs and a `Contents.json` single-size (1024) entry carrying
  `luminosity: dark` and `tinted` appearance variants (light = no appearance).

`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
(`ElementX/SupportingFiles/target.yml`) is unchanged — it resolves to the
appiconset by name. `Assets.xcassets` is already in the target's resources
(`- path: ../Resources`), so no build-setting edits are needed.

## Build & verify

1. `xcodegen` to regenerate `ElementX.xcodeproj` after the `app.yml` /
   resource changes.
2. `build-for-testing` (plain `build` fails on the pre-existing
   BuildExtensions error on this machine) to confirm the icon compiles and
   the rename builds.

## Snapshots

The rename changes app-name text in snapshot-tested previews
(onboarding, server-confirmation…). Follow the established fork workflow:
add the `record-snapshots` label to the PR so upstream CI re-records and
pushes the snapshot commit; approve the resulting "Element CI" run.

## Docs

Add a "Fork branding" note to `docs/fork-slimming.md` so future upstream
merges preserve the Neutrino name settings and the appiconset-for-.icon
swap (both permanently diverge from upstream).

## Out of scope

Alternate app icons, marketing/App-Store icon variants, nightly banner
(`IS_NIGHTLY_BUILD` stays false), any bundle-ID or target rename.
