# Telegram Tab Bar (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settings becomes a persistent 4th tab (Chats / Spaces / Search / Settings — nothing hidden), all settings entry points select that tab instead of presenting a sheet, and the tab bar's one non-Telegram detail (blue badge) turns Telegram red.

**Architecture:** The existing `NavigationTabCoordinator<HomeTab>` is a real SwiftUI `TabView` with a programmatic `selectedTab` — we add a `.settings` case and a long-lived `SettingsFlowCoordinator` mounted on its own `NavigationStackCoordinator` as the 4th tab. The old sheet path stays ONLY for the Mac detached-window branch (`startSettingsFlow(detached: true)`); the state machine's `.settingsScreen` states go dormant but stay untouched (minimal upstream diff). A `hidesDoneButton` flag threads through the settings screen so the tab root has no dangling Done button. Colors are already Telegram (Phase 1 theme layer); the only appearance edit is the tab badge → red.

**Tech Stack:** Swift 6.2, SwiftUI, MVVM-C flow coordinators, XCTest (existing `UserSessionFlowCoordinatorTests` conventions), XcodeGen.

## Global Constraints

- Branch: `feature/telegram-tab-bar` (already exists, cut from post-merge develop 415b8ab79).
- **Never push or PR to upstream `element-hq`** — all `gh` commands need `--repo khamitovdr/element-x-ios`.
- `xcodebuild` needs prefix `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; simulator tests add `CODE_SIGNING_ALLOWED=NO`; simulator is "iPhone 17"; plain simulator `build` fails on pre-existing BuildExtensions error — use `test`/`build-for-testing`.
- No new files in this plan → **no xcodegen runs needed**.
- Git pre-commit hook runs SwiftFormat and aborts on warnings — if a commit is rejected, the hook already auto-fixed the files: re-stage and re-commit.
- Every edit of an upstream-owned file carries a `TG-SKIN` comment marker; new marked files get rows in `docs/fork-slimming.md`'s TG-SKIN inventory (that section exists since Phase 1).
- App/UnitTests targets have `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — no redundant `@MainActor`. **Any closure UIKit may call off-main must be `nonisolated`** (Phase 1 crash lesson; none expected here, but if you add a `UIColor { … }` provider, it must live in `nonisolated` scope).
- Strings: use existing `L10n.commonSettings` for the tab title — do NOT add new strings or touch `Localizable.strings`.
- Icons: `TabDetails` takes `KeyPath<CompoundIcons, Image>` (not SF Symbols). Settings tab uses `\.settings` / `\.settingsSolid` (the gear pair, matching the outline/solid pattern of the other tabs). Existing tabs' icons are already the closest Compound equivalents of Telegram's — unchanged.
- Commit messages: title + body ending `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- PreviewTests are unaffected by design (previews don't render the tab coordinator); UI Tests (`UserSessionScreenTests`) snapshots WILL go stale — the fork's CI does not run the UI Tests workflow (only unit-tests/Danger/zizmor ran on PRs #3/#6), so note staleness in the PR body rather than re-recording.

### Key facts from research (with file:line anchors)

- `HomeTab` enum: `ElementX/Sources/FlowCoordinators/UserSessionFlowCoordinator.swift:23` — `enum HomeTab: Hashable { case chats, spaces, search }`.
- Tabs assembled at `UserSessionFlowCoordinator.swift:121-128`; `setTabs` resets selection to the FIRST tab, so appending settings keeps chats as default.
- `NavigationTabCoordinator.setTabs` diffing calls `start()` on inserted coordinators — but `SettingsFlowCoordinator.start()` is `fatalError("Unavailable")`. **The tab's coordinator is the `NavigationStackCoordinator`** (whose `start()` is harmless), NOT the flow coordinator — same shape as the search tab. The flow coordinator is only retained by `UserSessionFlowCoordinator`.
- `SettingsFlowCoordinator` (`ElementX/Sources/FlowCoordinators/SettingsFlowCoordinator.swift:20-50`): init takes `appLockService`, `isInSecondaryWindow`, `navigationStackCoordinator` (passed in, not owned), `flowParameters`. Populate its root by calling `handleAppRoute(.settings, animated: false)` EXACTLY ONCE — calling it again re-sets the root and duplicates an internal subscription.
- Settings sheet flow: `startSettingsFlow(detached:)` at `UserSessionFlowCoordinator.swift:358-400`; `handleAppRoute` settings branch at `:144-158` with the `isiOSAppOnMac` detached-window special case; spaces tab's `.showSettings` fires `stateMachine.tryEvent(.showSettingsScreen)` at `:258-259`.
- Done button: `SettingsScreen.swift:235-240` toolbar is unconditional; `.close` view action → `SettingsScreenCoordinatorAction.dismiss` → flow `.dismiss` action.
- Tab appearance choke point: `NavigationTabCoordinator.swift:348-354` `configureAppearance` — currently sets ONLY badge background = `.compound.iconAccentPrimary` (blue). Telegram's `tabBar.badgeBackgroundColor` = `0xFF3B30` light / red family dark → `.compound.bgCriticalPrimary` (mapped in Phase 1 to `0xFF3B30`/`0xEB5545`).
- Unit tests asserting the old sheet behavior: `UnitTests/Sources/UserSessionFlowCoordinatorTests.swift` — `settingsPresentation` (~lines 85-89), `roomPresentationClearsSettings`, `shareMediaRouteWithoutRoom`, `shareTextRouteWithoutRoom` (the share ones assert settings sheet is cleared before presenting the share sheet).

---

### Task 1: Settings tab in UserSessionFlowCoordinator

**Files:**
- Modify: `ElementX/Sources/FlowCoordinators/UserSessionFlowCoordinator.swift` (enum `:23`, new properties near `:46`, init tab construction `:99-128`, `handleAppRoute` `:144-158`, spaces sink `:258-259`)
- Test: `UnitTests/Sources/UserSessionFlowCoordinatorTests.swift`

**Interfaces:**
- Consumes: existing `SettingsFlowCoordinator` init (unchanged in this task — the `hidesDoneButton` flag is Task 2; until then the tab root shows a harmless Done button whose `.dismiss` is a no-op).
- Produces: `HomeTab.settings` case; stored `settingsTabFlowCoordinator: SettingsFlowCoordinator` (used by Task 2's flag only at construction); all settings entry points route through `handleAppRoute(.settings/.chatBackupSettings)` → tab selection.

- [ ] **Step 1: Rewrite the sheet-asserting tests as tab-asserting tests (failing first)**

In `UnitTests/Sources/UserSessionFlowCoordinatorTests.swift`, DELETE the existing `settingsPresentation`-style test (it asserts the sheet) and add these two tests in its place, reusing the file's existing setup/scaffolding conventions (read a neighboring route-handling test first and copy its setup lines; adapt property names like `userSessionFlowCoordinator`/`tabCoordinator` to what the file actually uses):

```swift
    func testSettingsRouteSelectsSettingsTab() async throws {
        userSessionFlowCoordinator.handleAppRoute(.settings, animated: false)
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(tabCoordinator?.selectedTab, .settings)
        XCTAssertNil(tabCoordinator?.sheetCoordinator, "Settings must be a tab, not a sheet")

        let settingsStack = tabCoordinator?.tabCoordinators.last as? NavigationStackCoordinator
        XCTAssertTrue(settingsStack?.rootCoordinator is SettingsScreenCoordinator,
                      "The last tab's root must be the settings screen")
    }

    func testRoomRouteWhileSettingsTabSelected() async throws {
        userSessionFlowCoordinator.handleAppRoute(.settings, animated: false)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(tabCoordinator?.selectedTab, .settings)

        userSessionFlowCoordinator.handleAppRoute(.room(roomID: "1", via: []), animated: false)
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(tabCoordinator?.selectedTab, .chats,
                       "Room routes must switch back to the chats tab")
    }
```

Adapt the exact coordinator/property names (`userSessionFlowCoordinator`, `tabCoordinator`) to what the test file already uses — read its existing tests first; the file already has a `tabCoordinator` accessor and route-handling tests to copy setup from. Update `roomPresentationClearsSettings` / `shareMediaRouteWithoutRoom` / `shareTextRouteWithoutRoom` in the same pass: wherever they asserted the settings **sheet** exists/clears, assert `selectedTab` transitions instead (settings tab selected → route → chats/share behavior with `sheetCoordinator` used only by the share sheet). Do not delete their share-sheet assertions — only the settings-sheet ones.

- [ ] **Step 2: Run the rewritten tests to verify they fail**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/UserSessionFlowCoordinatorTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15
```

Expected: **BUILD FAILED** (`HomeTab` has no member `settings`) — a compile-error red is acceptable here since the enum case doesn't exist yet.

- [ ] **Step 3: Implement the settings tab**

All edits in `ElementX/Sources/FlowCoordinators/UserSessionFlowCoordinator.swift`:

3a. The enum (line 23):

```swift
enum HomeTab: Hashable { case chats, spaces, search, settings } // TG-SKIN: + settings
```

3b. New stored properties next to the existing `settingsFlowCoordinator` (~line 46; keep that transient one — it still serves the Mac detached window):

```swift
    // TG-SKIN: settings is a persistent 4th tab (Telegram UX). The transient
    // settingsFlowCoordinator above remains only for the Mac detached window.
    private let settingsTabFlowCoordinator: SettingsFlowCoordinator
    private let settingsTabDetails: NavigationTabCoordinator<HomeTab>.TabDetails
```

3c. In `init`, after the search-tab block (line 113) and before the `tabs` array is built (line 121) — note `appLockService` must already be assigned at this point; if it's assigned later in init, place this block right after that assignment and before `setTabs`:

```swift
        // TG-SKIN: mount settings as a persistent tab. Route it exactly once —
        // repeat routing re-sets the root and duplicates subscriptions.
        let settingsStackCoordinator = NavigationStackCoordinator()
        settingsTabFlowCoordinator = SettingsFlowCoordinator(appLockService: appLockService,
                                                             isInSecondaryWindow: false,
                                                             navigationStackCoordinator: settingsStackCoordinator,
                                                             flowParameters: flowParameters)
        settingsTabDetails = .init(tag: HomeTab.settings, title: L10n.commonSettings, icon: \.settings, selectedIcon: \.settingsSolid)
        settingsTabFlowCoordinator.handleAppRoute(.settings, animated: false)
```

3d. Subscribe to its actions in the same place the other tab flow coordinator sinks live (inside `setupObservers()` if that's where `chatsTabFlowCoordinator`'s sink is, otherwise directly in init after 3c — match the file's existing pattern):

```swift
        settingsTabFlowCoordinator.actions.sink { [weak self] action in
            guard let self else { return }
            switch action {
            case .dismiss:
                break // TG-SKIN: tab roots aren't dismissed (Done button hidden in the tab).
            case .clearCache:
                actionsSubject.send(.clearCache)
            case .runLogoutFlow:
                Task { await self.runLogoutFlow() } // No sheet to dismiss first (unlike the sheet path).
            case .forceLogout:
                actionsSubject.send(.forceLogout)
            }
        }
        .store(in: &cancellables)
```

3e. Append the tab (after line 127's search-tab append):

```swift
        tabs.append(.init(coordinator: settingsStackCoordinator, details: settingsTabDetails)) // TG-SKIN
```

3f. Retarget `handleAppRoute` (lines 144-158). Keep the Mac branch verbatim; replace the else branch:

```swift
        case .settings, .chatBackupSettings:
            if ProcessInfo.processInfo.isiOSAppOnMac, flowParameters.windowManager.secondaryWindowsEnabled {
                startSettingsFlow(detached: true)
            } else {
                // TG-SKIN: settings is a tab; forward only sub-routes (the root is already mounted).
                navigationTabCoordinator.selectedTab = .settings
                if case .chatBackupSettings = appRoute {
                    settingsTabFlowCoordinator.handleAppRoute(appRoute, animated: animated)
                }
            }
```

3g. Retarget the spaces tab's `.showSettings` sink (lines 258-259):

```swift
            case .showSettings:
                self.handleAppRoute(.settings, animated: true) // TG-SKIN: was tryEvent(.showSettingsScreen)
```

Leave the state machine's `.settingsScreen` state, its `.showSettingsScreen`/`.dismissedSettingsScreen` events, `startSettingsFlow(detached: false)`'s body, and `clearPresentedSheets` untouched — dormant on iOS, still live for Mac; deleting them buys nothing and costs merge conflicts.

- [ ] **Step 4: Run the tests to verify they pass**

Same command as Step 2. Expected: **TEST SUCCEEDED** — the rewritten settings/room-route tests and all other `UserSessionFlowCoordinatorTests` pass.

- [ ] **Step 5: Lint and commit**

```bash
cd /Users/khamit/element_x_ios_fork && swiftformat --lint . && swiftlint lint --quiet
git add ElementX/Sources/FlowCoordinators/UserSessionFlowCoordinator.swift UnitTests/Sources/UserSessionFlowCoordinatorTests.swift
git commit -m "Mount settings as a persistent fourth tab

Telegram-style navigation: Chats/Spaces/Search keep their places and
Settings joins the tab bar instead of presenting as a sheet. All
settings entry points (deep links, avatar button, spaces tab) now
select the tab; the sheet machinery stays only for the Mac detached
window. TG-SKIN marked.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Hide the Done button on the settings tab root

**Files:**
- Modify: `ElementX/Sources/FlowCoordinators/SettingsFlowCoordinator.swift` (init + `presentSettingsScreen`)
- Modify: `ElementX/Sources/Screens/Settings/SettingsScreen/SettingsScreenCoordinator.swift` (parameters struct + VM construction)
- Modify: `ElementX/Sources/Screens/Settings/SettingsScreen/SettingsScreenModels.swift` (`ViewState`)
- Modify: `ElementX/Sources/Screens/Settings/SettingsScreen/SettingsScreenViewModel.swift` (init)
- Modify: `ElementX/Sources/Screens/Settings/SettingsScreen/View/SettingsScreen.swift:235-240` (toolbar)
- Modify: `ElementX/Sources/FlowCoordinators/UserSessionFlowCoordinator.swift` (pass the flag at the Task-1 construction site)
- Test: `UnitTests/Sources/SettingsScreenViewModelTests.swift`

**Interfaces:**
- Consumes: Task 1's `settingsTabFlowCoordinator` construction site.
- Produces: `SettingsFlowCoordinator.init(appLockService:isInSecondaryWindow:isRootOfTab:navigationStackCoordinator:flowParameters:)` with `isRootOfTab: Bool = false`; `SettingsScreenViewState.hidesDoneButton: Bool`.

- [ ] **Step 1: Write the failing test**

Read `UnitTests/Sources/SettingsScreenViewModelTests.swift` first and match its existing setup helper. Add (adapting the view-model construction to the file's existing helper — every existing test constructs the VM somehow; copy that and add the new argument):

```swift
    func testDoneButtonHiddenWhenRootOfTab() {
        let viewModel = makeViewModel(hidesDoneButton: true)
        XCTAssertTrue(viewModel.context.viewState.hidesDoneButton)
    }

    func testDoneButtonShownByDefault() {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.context.viewState.hidesDoneButton)
    }
```

If the file has no `makeViewModel` helper, extend whatever per-test construction it uses with a `hidesDoneButton: Bool = false` parameter.

- [ ] **Step 2: Run to verify failure**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/SettingsScreenViewModelTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

Expected: **BUILD FAILED** (no `hidesDoneButton` anywhere yet).

- [ ] **Step 3: Thread the flag**

3a. `SettingsScreenModels.swift` — add to `SettingsScreenViewState` (match the struct's existing property style; most VM-set fields are `var` with defaults):

```swift
    var hidesDoneButton = false // TG-SKIN: true when the screen is a tab root
```

3b. `SettingsScreenViewModel.swift` — add `hidesDoneButton: Bool = false` as the last init parameter and set it on the initial state, e.g. if the init currently builds `super.init(initialViewState: SettingsScreenViewState(...))`, add `hidesDoneButton: hidesDoneButton` to that construction (or assign `state.hidesDoneButton = hidesDoneButton` right after `super.init` if the state is built without it — match the file).

3c. `SettingsScreenCoordinator.swift` — add to `SettingsScreenCoordinatorParameters`:

```swift
    var hidesDoneButton = false // TG-SKIN
```

and pass it through where the coordinator constructs the view model: `hidesDoneButton: parameters.hidesDoneButton`.

3d. `SettingsScreen.swift` toolbar (lines 235-240) — wrap the item:

```swift
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if !context.viewState.hidesDoneButton { // TG-SKIN: tab roots have no Done
            ToolbarItem(placement: .primaryAction) {
                ToolbarButton(role: .close) { context.send(viewAction: .close) }
                    .accessibilityIdentifier(A11yIdentifiers.settingsScreen.done)
            }
        }
    }
```

(Keep the existing body inside the `if` exactly as it is in the file — the snippet above shows the current body from research; verify against the file.)

3e. `SettingsFlowCoordinator.swift` — add `isRootOfTab: Bool = false` to init (stored as `private let isRootOfTab: Bool`), and in `presentSettingsScreen` pass `hidesDoneButton: isRootOfTab` into `SettingsScreenCoordinatorParameters`.

3f. `UserSessionFlowCoordinator.swift` — at the Task-1 construction site add `isRootOfTab: true`:

```swift
        settingsTabFlowCoordinator = SettingsFlowCoordinator(appLockService: appLockService,
                                                             isInSecondaryWindow: false,
                                                             isRootOfTab: true,
                                                             navigationStackCoordinator: settingsStackCoordinator,
                                                             flowParameters: flowParameters)
```

- [ ] **Step 4: Run to verify pass (both suites)**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/SettingsScreenViewModelTests \
  -only-testing:UnitTests/UserSessionFlowCoordinatorTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

Expected: **TEST SUCCEEDED**.

- [ ] **Step 5: Lint and commit**

```bash
cd /Users/khamit/element_x_ios_fork && swiftformat --lint . && swiftlint lint --quiet
git add ElementX/Sources/FlowCoordinators/SettingsFlowCoordinator.swift ElementX/Sources/Screens/Settings/SettingsScreen UnitTests/Sources/SettingsScreenViewModelTests.swift ElementX/Sources/FlowCoordinators/UserSessionFlowCoordinator.swift
git commit -m "Hide the settings Done button when mounted as a tab root

A tab root has nothing to dismiss; hidesDoneButton threads from the
flow coordinator through the screen parameters and view state to the
toolbar. Sheet and detached-window presentations keep their Done
button. TG-SKIN marked.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Telegram-red tab badge + playbook rows

**Files:**
- Modify: `ElementX/Sources/Application/Navigation/NavigationTabCoordinator.swift:348-354` (`configureAppearance`)
- Modify: `docs/fork-slimming.md` (TG-SKIN inventory + fork-owned notes)

**Interfaces:** none new — pure restyle + docs.

- [ ] **Step 1: Swap the badge color**

In `configureAppearance`, replace the three `badgeBackgroundColor` assignments' value `.compound.iconAccentPrimary` with `.compound.bgCriticalPrimary`, and add one marker comment above the first:

```swift
        // TG-SKIN: Telegram's tab badge is red (tabBar.badgeBackgroundColor), not accent.
        standardAppearance.stackedLayoutAppearance.normal.badgeBackgroundColor = .compound.bgCriticalPrimary // iPhone Portrait
        standardAppearance.compactInlineLayoutAppearance.normal.badgeBackgroundColor = .compound.bgCriticalPrimary // iPhone Landscape
        standardAppearance.inlineLayoutAppearance.normal.badgeBackgroundColor = .compound.bgCriticalPrimary // iPadOS 17 (doesn't work for 18+)
```

No other appearance changes: the blurred default background and window-tint selected color already match Telegram via the Phase 1 theme layer.

- [ ] **Step 2: Verify it builds + tab coordinator tests still pass**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/NavigationTabCoordinatorTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Expected: **TEST SUCCEEDED**.

- [ ] **Step 3: Update the playbook**

In `docs/fork-slimming.md`, TG-SKIN marker inventory table, add rows (match existing format):

```markdown
| `ElementX/Sources/FlowCoordinators/UserSessionFlowCoordinator.swift` | HomeTab.settings case, persistent settings tab mounting + action sink, handleAppRoute/spaces-sink retarget to tab |
| `ElementX/Sources/FlowCoordinators/SettingsFlowCoordinator.swift` | `isRootOfTab` init flag → hidesDoneButton |
| `ElementX/Sources/Screens/Settings/SettingsScreen/*` (Coordinator, Models, ViewModel, View) | `hidesDoneButton` threading + conditional Done toolbar |
| `ElementX/Sources/Application/Navigation/NavigationTabCoordinator.swift` | tab badge → bgCriticalPrimary (Telegram red) |
```

Also append one line to the post-merge checklist: `After merging upstream changes to UserSessionFlowCoordinator, re-verify: settings entry points still select the tab (run UserSessionFlowCoordinatorTests), and the dormant sheet path is only reachable via the Mac detached branch.`

- [ ] **Step 4: Commit**

```bash
git add ElementX/Sources/Application/Navigation/NavigationTabCoordinator.swift docs/fork-slimming.md
git commit -m "Restyle the tab badge Telegram-red and inventory Phase 2 markers

The blurred background and blue selected tint already come from the
theme layer; the badge was the one remaining non-Telegram detail.
Playbook gains the Phase 2 TG-SKIN rows and a post-merge check.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Verify (full suite, simulator, device) and open the PR

**Files:** none (verification + PR). Run by the controller (needs the user's iPhone).

- [ ] **Step 1: Full unit-test pass on the affected suites**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/UserSessionFlowCoordinatorTests \
  -only-testing:UnitTests/SettingsScreenViewModelTests \
  -only-testing:UnitTests/NavigationTabCoordinatorTests \
  -only-testing:UnitTests/TelegramThemeHookTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Expected: **TEST SUCCEEDED**.

- [ ] **Step 2: Device build, install, RELAUNCH**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project ElementX.xcodeproj -scheme ElementX -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/neutrino-tab-bar -allowProvisioningUpdates -allowProvisioningDeviceRegistration 2>&1 | tail -1
xcrun devicectl list devices   # confirm the iPhone is available; ask the user to unlock if not
xcrun devicectl device install app --device 4DFB4261-21F9-5982-AE2A-11E1D6554C00 \
  /tmp/neutrino-tab-bar/Build/Products/Debug-iphoneos/ElementX.app
xcrun devicectl device process launch --terminate-existing --device 4DFB4261-21F9-5982-AE2A-11E1D6554C00 com.khamitovdr.elementx
```

(Install NEVER restarts a running app — the relaunch step is mandatory; Phase 1 lesson.)

User verification checklist: 4th "Settings" gear tab appears and opens settings in place (no sheet, no Done button); avatar button now also lands on the tab; Chats/Spaces/Search unchanged; unread badge on the Chats tab is red; logout confirmation still works from the tab.

- [ ] **Step 3: Push and open the PR**

```bash
git push -u origin feature/telegram-tab-bar
gh pr create --repo khamitovdr/element-x-ios --base develop \
  --title "Add a Settings tab and Telegram-style tab badge" \
  --label pr-feature \
  --body "$(cat <<'EOF'
Phase 2 of the Telegram skin (plan: docs/superpowers/plans/2026-07-16-telegram-tab-bar.md): Settings becomes a persistent 4th tab mounted on the existing SettingsFlowCoordinator; all entry points (deep links, avatar button, spaces tab) select the tab instead of presenting a sheet, which remains only for the Mac detached window. The tab root hides its Done button via a hidesDoneButton flag threaded through the settings screen. The tab badge turns Telegram red (bgCriticalPrimary); background blur and blue selected tint already come from the Phase 1 theme layer.

UserSessionScreenTests (UI test) snapshots go stale for tab-bar-visible steps — the fork's CI does not run the UI Tests workflow, noted per playbook.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 4: Watch CI; merge once green AND the user has verified on device**

```bash
gh pr checks <PR#> --repo khamitovdr/element-x-ios --watch
gh pr merge <PR#> --repo khamitovdr/element-x-ios --merge
git checkout develop && git pull origin develop
```

(Per the user's standing authorization: CI-watch and merge are autonomous; the user's on-device verification is the only human gate.)
