# Slim fork design — hide unused features, excise heavy packages

**Date:** 2026-07-15
**Status:** Approved
**Fork:** `khamitovdr/element-x-ios`, serving the private homeserver `branga.ru` (password auth only, federation off, invite-token registration).

## Goals

- Lighter UI: only the features the community actually uses.
- Faster clean builds: remove heavy packages that serve dropped features.
- Stay mergeable with `upstream/develop`: prefer flags and fork-owned files; keep unavoidable edits leaf-level and documented.
- Login pinned to `branga.ru`, changeable by editing one array literal.

## Non-goals

- Freezing from upstream or rewriting architecture.
- Touching E2EE plumbing (session verification, secure backup, recovery, encryption reset).
- Removing test targets or trimming localizations (no build-speed win; merge pain).
- Server-side changes.

## Decisions (user-confirmed)

| Feature | Decision |
|---|---|
| Audio/video calls (Element Call/LiveKit) | Keep |
| Voice messages, round videos, polls | Keep |
| Location sharing (incl. live location) | Remove + drop MapLibre |
| Threads | Hide via flags |
| Spaces | Zero-touch (UI self-hides when account has no spaces) |
| Knocking | Hide via flag |
| Report content / report room | Hide entry points |
| Analytics (PostHog), crash reporting (Sentry) | Remove packages |
| Bug reporting (rageshake) | Self-hides once `Secrets.swift` is nilled out; strip Sentry integration |
| Server picker / link new device | Pin provider, hide via flags |
| QR-code login | One-line edit: the button is only gated by "not on Mac", so it does NOT self-hide — force it off in the pinned-provider branch |
| Room directory search ("explore rooms") | Hide entry point |
| E2EE screens, member/roles management, search, pinned events, app lock | Keep untouched |

## Architecture

Two layers, in one PR (mostly deletions):

### Layer 1 — Config (fork-owned files, zero merge cost)

Upstream provides `AppHooksProtocol.setUp()` as a deliberate no-op extension point
(`ElementX/Sources/AppHooks/AppHooks.swift`) and `AppHooks.registerAppSettingsHook(_:)`.

New fork-owned files:

1. `ElementX/Sources/AppHooks/Hooks/ForkAppSettingsHook.swift` — implements
   `AppSettingsHookProtocol.configure(_:)`:
   - `appSettings.override(accountProviders: ["branga.ru"], allowOtherAccountProviders: false, …)`
     passing through upstream defaults for parameters we don't change.
   - Force off on every launch (idempotent, beats stale persisted toggles):
     `threadsEnabled`, `roomThreadListEnabled`, `knockingEnabled`, `linkNewDeviceEnabled`.
2. `ElementX/Sources/AppHooks/AppHooks+Fork.swift` — `extension AppHooks` with a concrete
   `setUp()` registering `ForkAppSettingsHook`. `AppHooks` already conforms to
   `AppHooksProtocol`, whose `setUp()` default is an empty protocol-extension method;
   a concrete method wins over it. This is upstream's intended fork mechanism.

Because the flags are forced off each launch, their user-facing toggles must not be shown:
- Remove the threads section from `Screens/LabsScreen/View/LabsScreen.swift`.
- Remove the knocking toggle from `Screens/Settings/DeveloperOptionsScreen/`.

### Layer 2 — Excision (small, contained upstream edits)

**MapLibre + location sharing.** Research showed only THREE files import MapLibre
(`MapLibreMapView`, `LocationAnnotation`, `TargetConfiguration`), while full deletion of
location code would ripple through ~20 upstream-hot files (TimelineViewModel,
RoomFlowCoordinator, proxies, mocks). So: remove the `MapLibre` package from `project.yml`,
rewrite the two MapLibre-importing wrapper files IN PLACE as API-compatible stubs
(placeholder imagery, same type names/initializers), and drop the MapLibre configuration
from `TargetConfiguration`. `Screens/LocationSharing/`, `Services/Location/` and
`MapTilerSettings` stay compiled but unreachable: with `Secrets.mapLibreAPIKey == nil`,
upstream's own gating (`mapTilerSettings.isEnabled`) hides the composer "Location" option
and disables location-bubble taps — no edits to `RoomAttachmentPicker` or flow coordinators.
Timeline fallback: `LocationRoomTimelineView` always renders the textual description
(`FormattedBodyText`), `LiveLocationRoomTimelineView` renders the bundled blurred-map asset;
no Apple Maps hand-off (tap entry points are disabled, and received locations are rare
once sending is removed).

**PostHog + Sentry.** Remove both packages from `project.yml`. Delete the four PostHog
files and replace the client with a fork-owned `NoOpAnalyticsClient`. Sentry is more
entangled than two files (Signposter spans, `.sentryTrace` view modifiers, `setupSentry`,
crash detection): keep every signature and gut bodies — no-op `Signposter`, empty
`setupSentry`, `crashedLastRun = false` — so the dozens of call sites stay untouched.
Keep the `AnalyticsEvents` package: tiny, pure Swift, threaded through dozens of
`analytics.track(…)` call sites; upstream's keyless-build path no-ops analytics at runtime.

**Secrets.** The fork's committed `Secrets/Secrets.swift` carries non-nil localhost
placeholders, so the analytics consent prompt and bug-report row are currently VISIBLE.
Nil every value: this activates upstream's disabled paths for analytics, Sentry and
rageshake, and disables MapTiler (hiding all location entry points).

**Entry-point hides.** Remove menu items / buttons only (screens may stay compiled):
- "Report content" in the timeline item menu; "Report room" in room details.
- Room directory / "explore rooms" entry on the home/start-chat flow.

**Tests.** Delete unit/preview/snapshot tests that belong to deleted sources.
Sourcery regenerates mocks and preview dictionaries, shrinking them automatically.

## Merge playbook

New `docs/fork-slimming.md` documents every upstream file the fork edits, with the rule:
**on merge conflict, take upstream's version, then re-apply the exclusion.** Expected
conflict spots: `project.yml`/`target.yml` (packages), `Secrets.swift`, `AppCoordinator`,
`Signposter`, `BugReportService`, the MapLibre wrapper stubs,
`LocationRoomTimelineView.swift` / `LiveLocationRoomTimelineView.swift`,
`AuthenticationStartScreenViewModel.swift` (QR), `LabsScreen.swift` + Settings row,
`DeveloperOptionsScreen`, and the report/directory entry points. Fork-owned files
(`ForkAppSettingsHook`, `AppHooks+Fork`, `NoOpAnalyticsClient`) never conflict.

## Error handling

- Location messages received from other clients must never crash or render blank:
  static locations render their textual description (`FormattedBodyText`), live shares
  render the bundled blurred-map asset.
- If upstream changes `AppSettings.override(…)`'s signature, the fork hook fails to
  compile — a loud, easy fix, preferred over silent drift.

## Verification

On-simulator (build with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild …`):

1. Fresh install → login goes straight to the branga.ru password form; no server picker, no QR option.
2. Attach menu shows photo/video/file/poll — no Location.
3. A location message sent from Element Web renders as a text bubble (description/geo URI), no spinner.
4. Element Call starts; a poll can be created; voice message and round video record.
5. No threads UI, no knock UI, no report menu items, no analytics/bug-report settings rows,
   no explore-rooms entry.
6. Labs shows no threads toggle; developer options show no knocking toggle.
7. `swiftformat --lint .` and `swiftlint lint` pass (hooks may not be installed locally).

## Constraints

- PR targets `khamitovdr/element-x-ios` `develop` (never upstream), one `pr-` label,
  sentence-style title. The change is deletion-heavy; if docs push additions past the
  500-additions Danger limit, that warning is acceptable on this personal fork.
- Expectation: big wins are UI simplicity and merge safety; clean-build speedup is
  moderate (MapLibre is the heavyweight); incremental builds barely change.
