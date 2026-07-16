# Fork slimming — merge playbook

This fork hides/removes features for the private branga.ru deployment.
Rule for upstream merge conflicts in the files below: **take upstream's
version, then re-apply the listed exclusion.** Fork-owned files never
conflict.

## Fork-owned files (never conflict)
- ElementX/Sources/AppHooks/Hooks/ForkAppSettingsHook.swift — pins accountProviders (change server here), forces flags off
- ElementX/Sources/AppHooks/AppHooks+Fork.swift — registers the hook
- ElementX/Sources/Services/Analytics/NoOpAnalyticsClient.swift
- UnitTests/Sources/ForkAppSettingsHookTests.swift

Note: `Secrets/Secrets.swift` is **not** in this list even though it's
fork-changed — it's an upstream-tracked file (not gitignored) whose six
values this fork nils out. Treat it like any other row in the table below.

## Upstream files edited (conflict candidates)
| File | Exclusion to re-apply |
|---|---|
| .github/workflows/unit-tests.yml | Codecov coverage upload non-fatal (no CODECOV_TOKEN on the fork) |
| project.yml | MapLibre, PostHog, Sentry package blocks removed |
| ElementX/SupportingFiles/target.yml | MapLibre/PostHog/Sentry package links removed |
| UITests/SupportingFiles/target.yml | PostHog/Sentry links removed |
| IntegrationTests/SupportingFiles/target.yml | Sentry link removed (this target never linked PostHog) |
| Secrets/Secrets.swift | all values nil |
| ElementX/Sources/Application/AppCoordinator.swift | NoOpAnalyticsClient; setupSentry body emptied; no Sentry import |
| ElementX/Sources/Services/Analytics/Signposter.swift | no-op bodies, no Sentry types (imports Foundation instead) |
| ElementX/Sources/Services/Analytics/AnalyticsService.swift | no PostHog import |
| ElementX/Sources/Services/BugReport/BugReportService.swift | crashedLastRun = false, no Sentry import |
| ElementX/Sources/Screens/HomeScreen/View/HomeScreen.swift, HomeScreenContent.swift, ElementX/Sources/Screens/RoomScreen/View/RoomScreen.swift | no `.sentryTrace` / SentrySwiftUI (three call sites) |
| ElementX/Sources/Other/MapLibre/MapLibreMapView.swift, LocationAnnotation.swift | placeholder stubs, no MapLibre import; `LocationAnnotationView` (the MLN annotation subclass) deleted outright rather than stubbed |
| ElementX/Sources/Application/TargetConfiguration.swift | no MapLibre configuration |
| ElementX/Sources/Screens/Timeline/View/TimelineItemViews/LocationRoomTimelineView.swift, LiveLocationRoomTimelineView.swift | text-only fallback (LocationRoomTimelineView) / blurred-asset fallback (LiveLocationRoomTimelineView) instead of static map tiles |
| ElementX/Sources/Screens/Authentication/StartScreen/AuthenticationStartScreenViewModel.swift | QR button false in pinned branch |
| UnitTests/Sources/AuthenticationStartScreenViewModelTests.swift | additive fork test (`singleProviderHidesQRCodeLoginButton`) covering the QR-button exclusion — keep both sides on conflict |
| ElementX/Sources/Screens/LabsScreen/View/LabsScreen.swift + Settings SettingsScreen.swift | threads section + Labs row removed |
| ElementX/Sources/Screens/Settings/DeveloperOptionsScreen/View/DeveloperOptionsScreen.swift | knocking/thread-list/link-device toggles removed |
| ElementX/Sources/Screens/Timeline/View/ItemMenu/TimelineItemMenuActionProvider.swift | .report menu item removed |
| ElementX/Sources/Screens/RoomDetailsScreen/RoomDetailsScreenViewModel.swift, HomeScreen/HomeScreenViewModel.swift | reportRoomEnabled = false |
| ElementX/Sources/Screens/HomeScreen/HomeScreenViewModel.swift, JoinRoomScreen/JoinRoomScreenViewModel.swift | the two remaining `isReportRoomSupported` reads (invite-decline alert routing) collapsed to upstream's plain-alert else-branch, since the report capability is force-disabled anyway |
| ElementX/Sources/Screens/StartChatScreen/View/StartChatScreen.swift | room-directory row removed |
| UnitTests/Sources/HomeScreenViewModelTests.swift, JoinRoomScreenViewModelTests.swift | tests for the removed report-capable decline-and-block routing deleted (`declineAndBlockInvite`, `declineAndBlockInviteInteraction`); `declineInvite` adjusted to act on the plain alert's `secondaryButton` instead of a `verticalButtons` entry |
| UnitTests/Sources/BugReportServiceTests.swift | `configurations()` builds its own `RemotePreference` with an explicit default URL instead of reading the initial value from `AppSettings.bugReportRageshakeURL` (which is `.disabled` now that secrets are nil) |

## Deleted upstream files (git re-adds them on merge → delete again)
PostHogAnalyticsClient.swift, PHGPostHogProtocol.swift,
PHGPostHogConfiguration.swift, PHGPostHogMock.swift, SentryEvent.swift,
UnitTests AnalyticsTests.swift, UITests testLocationSharing() (and its
now-orphaned `allowLocationPermissionOnce()` helper in
UserSessionScreenTests.swift).

`ElementX/Sources/Mocks/Generated/GeneratedMocks.swift` also lost the
`PHGPostHogMock` case, but don't hand-edit it: it's Sourcery output and
regenerates automatically once `PHGPostHogProtocol.swift` is deleted again
and the target rebuilds.

`ElementX/Sources/Other/MapLibre/CoordinateAnimator.swift` is left in
place (nothing deleted it) but is now dead code — no remaining file
references it after `LocationAnnotationView` was removed. Safe to delete
in a follow-up if it starts bit-rotting; not required for merges to succeed.

## Fork branding (Neutrino)
The fork ships its own name and icon; both permanently diverge from upstream.
- `app.yml`: `APP_DISPLAY_NAME` and `PRODUCTION_APP_NAME` are both `Neutrino`
  (upstream: `Element X` / `Element`). On conflict, keep `Neutrino`. These
  two values drive every user-visible name — no source strings are patched.
- Icon: upstream's `ElementX/Resources/AppIcon.icon` (Icon Composer bundle)
  is **replaced** by `ElementX/Resources/Assets.xcassets/AppIcon.appiconset`
  (flat light/dark/tinted 1024² PNGs). `ASSETCATALOG_COMPILER_APPICON_NAME`
  stays `AppIcon`. If an upstream merge re-adds `AppIcon.icon`, **delete it
  again** — two assets named `AppIcon` fail the asset-catalog build.

## After every upstream merge
1. `grep -rn 'import MapLibre\|import PostHog\|import Sentry' ElementX UnitTests UITests` → fix new hits (stub or delete).
2. `xcodegen && build` — compiler finds signature drift (e.g. AppSettings.override), and regenerates `project.pbxproj`/`Package.resolved`/`GeneratedMocks.swift` so those generated/committed files don't need manual conflict resolution beyond what step 1 fixes at the source level.
3. Run UnitTests target.

## Snapshot tests (they DO run on this fork's CI)
The unit-tests workflow runs PreviewTests, so any fork edit that changes a
preview's rendering needs re-recorded snapshots. Do not record locally —
environments differ. Instead add the `record-snapshots` label to the PR:
upstream's Record Snapshots workflow re-records on CI and pushes a
"Record preview snapshots" commit as "Element CI". That commit's workflow
runs are gated as a first-time contributor — approve them with
`gh api -X POST repos/khamitovdr/element-x-ios/actions/runs/<id>/approve`.

## Fork CI facts
- `Unit Tests (Enterprise)` is disabled on the fork (`disabled_manually`) —
  it needs Element's private-submodule token and can never pass here.
- Local UnitTests runs show ~26 AppLock/Keychain failures (no signing
  identity); those same suites pass on GitHub CI. Trust CI for those.

## Telegram skin (TG-SKIN)

The fork re-skins the app to Telegram's Day/Night look.
Spec: `docs/superpowers/specs/2026-07-16-telegram-skin-design.md` ·
Palette truth: `docs/superpowers/specs/2026-07-16-telegram-palette-reference.md`

Mechanism: `TelegramThemeHook` (fork-owned, `ElementX/Sources/AppHooks/Hooks/`) overrides
Compound colour tokens at startup, registered via `registerCompoundHook` in
`AppHooks+Fork.setUp()` and applied by upstream's existing `AppCoordinator` call.
Raw values: `TelegramPalette.swift`. Previews/PreviewTests never run the hook, so
snapshots stay on stock Compound colours by design.

### TG-SKIN marker inventory (grep after every upstream merge)

| File | Edit |
|---|---|
| `compound-ios/Sources/Compound/Colors/CompoundColors.swift` | `decorativeColors` computed instead of stored, so runtime overrides reach avatars/sender names |

### Post-merge re-skin checklist

1. `grep -rn "TG-SKIN" --include="*.swift" .` — every inventory row still present? Re-apply any lost edit.
2. Upstream bumped `compound-design-tokens`? A renamed/removed token fails the build inside
   `TelegramThemeHook.mappings` — remap using the palette reference doc.
3. Run the theme suites: `TelegramPaletteTests`, `DecorativeColorOverrideTests`, `TelegramThemeHookTests`.
4. New upstream screens inherit the skin through tokens automatically; spot-check them for
   hardcoded colours and add spot fixes to the current phase's escape list.
