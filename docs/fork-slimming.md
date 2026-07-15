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
