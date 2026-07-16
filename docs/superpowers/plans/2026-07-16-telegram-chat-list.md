# Telegram Chat List (Phase 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The chat list looks like Telegram's: 60pt avatars, always-bold names, numeric unread pills (blue; gray when muted), mute icon beside the name, pin icon for favourites, text-aligned separators, Telegram folder-style filter tabs, and a clean nav bar (no avatar button, no bloom) — plus the carried-over settings pop-to-root fix.

**Architecture:** In-place `TG-SKIN`-marked restyles of `HomeScreenRoomCell` and the filter views; one new fork-owned badge view (`TelegramUnreadBadge`); a small `HomeScreenRoom.Badges` extension carrying a numeric `unreadCount`; toolbar/bloom edits in `HomeScreen.swift`; a `popToRoot` guard in `SettingsFlowCoordinator`. Colors come from the Phase 1 theme layer (`bgBadgeDefault` = Telegram blue, `bgBadgeSecondary` = muted gray, already mapped).

**Tech Stack:** Swift 6.2, SwiftUI, Compound tokens, Swift Testing/XCTest per file convention, XcodeGen (one new file), PreviewTests re-record via `record-snapshots` label.

## Global Constraints

- Branch: `feature/telegram-chat-list` (exists, cut from develop ac0f0bb98).
- **Never push or PR to upstream `element-hq`** — all `gh` commands need `--repo khamitovdr/element-x-ios`.
- `xcodebuild` prefix `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; simulator tests add `CODE_SIGNING_ALLOWED=NO`; simulator "iPhone 17"; use `test`/`build-for-testing` for simulator (plain `build` broken).
- Task 2 creates ONE new file → run `xcodegen` and `git add ElementX.xcodeproj` in that task; no other task adds files.
- Pre-commit hook runs SwiftFormat and aborts after auto-fixing — re-stage and re-commit.
- Every upstream-file edit carries a `TG-SKIN` marker; Task 6 adds the inventory rows.
- App/UnitTests default to MainActor — no redundant `@MainActor`; any closure UIKit calls off-main must be `nonisolated` (none expected).
- No new user-visible strings (all labels exist); never touch `Localizable.strings`.
- **Snapshots:** this phase changes `HomeScreenRoomCell_Previews`, `HomeScreen_Previews`, `RoomListFilterView(s)_Previews` and possibly empty-state previews. Do NOT re-record locally — Task 6 applies the `record-snapshots` label so Element CI re-records and pushes (then its gated runs get approved via API, per `docs/fork-slimming.md` fork CI facts).
- Commit messages: title + body ending `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

### Telegram reference values (transcribed from `ChatListItem.swift` et al., default text size — see the Phase 3 research in git history and `docs/superpowers/specs/2026-07-16-telegram-palette-reference.md` for colors)

| Metric | Telegram | Element X today |
|---|---|---|
| Avatar | 60pt, 16pt leading, 10pt gap to text | 52pt (`.room(on: .chats)`), 16pt insets, 16pt gap |
| Title | 16pt semibold ALWAYS | bodyLG(17) semibold only when unread |
| Preview | 15pt regular, 2 lines, `messageTextColor` gray | bodyMD ≈15, 2 lines, textSecondary ✓ |
| Date | 14pt regular top-right | bodySM ✓ top-right ✓ |
| Unread badge | numeric pill: 20pt tall, radius 10, min-width 20, 12pt semibold tabular digits, white-on-blue; gray when muted; empty 20pt circle for marked-unread | 12pt dot, no count |
| Mention badge | 20pt pill with @, left of unread pill, 6pt gap | 15pt @ icon in badges row |
| Mute icon | beside the title (after name), `muteIconColor` | in trailing badges row |
| Pin icon | far right, only when pinned AND no unread pill | none (fork maps favourites → pin) |
| Separator | hairline, leading-inset to text start (16+60+10=86pt) | full width under content |
| Vertical padding | ~8pt content top inset | 12pt |
| Date format | today→time, ≤6d→weekday, else date | `formattedMinimal()` already matches (uses "Yesterday" instead of weekday for 1 day — acceptable, keep) |

---

### Task 1: Numeric unread count on HomeScreenRoom

**Files:**
- Modify: `ElementX/Sources/Screens/HomeScreen/HomeScreenModels.swift` (`Badges` struct ~line 196, badge derivation in the `init(summary:...)` construction ~lines 257-307)
- Test: `UnitTests/Sources/HomeScreenRoomTests.swift`

**Interfaces:**
- Produces: `HomeScreenRoom.Badges.unreadCount: Int` and `HomeScreenRoom.Badges.isMuted: Bool` (rename-safe: keep the existing `isDotShown`, `isMentionShown`, `isMuteShown`, `callBadgeType` untouched — Task 2 consumes both old and new fields; invite cells keep using `isDotShown`).

**Semantics (Telegram-verbatim):**
- `unreadCount` = the number shown in the pill: for unmuted rooms `summary.unreadNotificationsCount`; for muted rooms `summary.unreadMessagesCount` (Telegram shows a gray count for muted chats). Apply the SAME `roomListActivityVisibility` gating the existing `isDotShown` derivation uses (read that code first — when activity is hidden, count is 0).
- `isMuted` = `summary.isMuted` (mirrors `isMuteShown`; explicit field so the cell doesn't overload meaning).
- Marked-unread with zero count keeps `isDotShown == true` (existing logic) — Task 2 renders that as an EMPTY pill.

- [ ] **Step 1: Write failing tests**

Read `UnitTests/Sources/HomeScreenRoomTests.swift` first; add tests in its idiom (construct the room from a mocked `RoomSummary` the way existing tests do — copy their summary-factory):

```swift
    // Unmuted room with notifications → blue-pill count from unreadNotificationsCount.
    func testUnreadCountForUnmutedRoom() {
        let room = makeRoom(unreadMessagesCount: 10, unreadNotificationsCount: 4, isMuted: false)
        XCTAssertEqual(room.badges.unreadCount, 4)
        XCTAssertFalse(room.badges.isMuted)
    }

    // Muted room → gray-pill count from unreadMessagesCount (Telegram semantics).
    func testUnreadCountForMutedRoom() {
        let room = makeRoom(unreadMessagesCount: 10, unreadNotificationsCount: 0, isMuted: true)
        XCTAssertEqual(room.badges.unreadCount, 10)
        XCTAssertTrue(room.badges.isMuted)
    }
```

(Adapt `makeRoom` to the file's existing factory — extend it with the needed summary parameters if required; if the file is Swift Testing, use `@Test`/`#expect`.)

- [ ] **Step 2: Run to verify failure**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/HomeScreenRoomTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -8
```

Expected: BUILD FAILED (`unreadCount` doesn't exist).

- [ ] **Step 3: Implement**

In `HomeScreenModels.swift` `Badges` struct add (TG-SKIN marked):

```swift
        // TG-SKIN: numeric Telegram-style pill count + explicit mute for gray styling.
        let unreadCount: Int
        let isMuted: Bool
```

In the construction init, derive them next to the existing badge derivation, following the gating described in **Semantics** above (read the existing `isDotShown` logic and mirror its activity-visibility gates; when gated off, `unreadCount = 0`). Update every `Badges(...)` construction site (there are placeholder/invite constructions too — grep `Badges(` in the file; placeholders/invites get `unreadCount: 0, isMuted: false` unless the invite already models unreads, in which case mirror its dot logic).

- [ ] **Step 4: Run to verify pass** — same command, expect TEST SUCCEEDED (whole `HomeScreenRoomTests` suite).

- [ ] **Step 5: Lint and commit**

```bash
swiftformat --lint . && swiftlint lint --quiet
git add ElementX/Sources/Screens/HomeScreen/HomeScreenModels.swift UnitTests/Sources/HomeScreenRoomTests.swift
git commit -m "Add numeric unread count to home screen room badges

Telegram-style pills need a number: unreadNotificationsCount for
unmuted rooms, unreadMessagesCount for muted ones (gray pill), gated
by the same activity-visibility rules as the existing dot. TG-SKIN.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Restyle HomeScreenRoomCell to the Telegram row

**Files:**
- Create: `ElementX/Sources/Screens/HomeScreen/View/TelegramUnreadBadge.swift`
- Modify: `ElementX/Sources/Screens/HomeScreen/View/HomeScreenRoomCell.swift`
- Modify: `ElementX/Sources/Other/Avatars.swift:157-159` (`RoomAvatarSizeOnScreen.chats` 52 → 60)
- Modify: `ElementX/Sources/Other/SwiftUI/RowDivider.swift` only if it can't take a leading inset already — prefer passing insets from the cell.
- Test: previews in the cell file (updated states) — snapshot re-record happens in Task 6; unit coverage rides on Task 1.

**Interfaces:**
- Consumes: `room.badges.unreadCount`, `room.badges.isMuted` (Task 1), existing `badges.isDotShown/isMentionShown/isMuteShown/callBadgeType`.
- Produces: `TelegramUnreadBadge(count: Int, isMuted: Bool)` SwiftUI view (fork-owned).

- [ ] **Step 1: Create the badge view**

`ElementX/Sources/Screens/HomeScreen/View/TelegramUnreadBadge.swift` (new fork-owned file; standard SPDX header WITH trailing period):

```swift
import SwiftUI

/// Telegram-style unread pill: 20pt tall, radius 10, 12pt semibold tabular digits,
/// white on the accent badge colour (grey when muted). A zero count renders an
/// empty 20pt circle (marked-unread). Metrics transcribed from ChatListItem.swift
/// + ChatListBadgeNode.swift in the vendored Telegram repo. TG-SKIN (fork-owned).
struct TelegramUnreadBadge: View {
    let count: Int
    let isMuted: Bool
    
    var body: some View {
        Text(count > 0 ? String(count) : "")
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.compound.textOnSolidPrimary)
            .padding(.horizontal, count > 9 ? 6 : 0)
            .frame(minWidth: 20)
            .frame(height: 20)
            .background(isMuted ? Color.compound.bgBadgeSecondary : .compound.bgBadgeDefault)
            .clipShape(Capsule())
    }
}
```

Token note: the pill is a SOLID blue/gray fill, so the text uses `textOnSolidPrimary` (white) — NOT `textBadgeAccent`, which the theme maps to accent-on-pale for the pale badge surfaces.

Run `xcodegen && git add ElementX.xcodeproj` after creating the file.

- [ ] **Step 2: Restyle the cell**

In `HomeScreenRoomCell.swift`, all edits TG-SKIN-marked:

2a. Avatar size: change `RoomAvatarSizeOnScreen.chats` in `Avatars.swift` from 52 to 60 (`// TG-SKIN: Telegram avatar diameter`). Grep `.room(on: .chats)` first — if any OTHER screen uses it, do NOT change the shared constant; instead give the cell its own 60pt size via `.custom(60)` if `AvatarSize` supports it (check the enum) and leave the constant alone. State in the report which route was taken and why.

2b. Spacing: `HStack(spacing: 16.0)` → `HStack(spacing: 10.0)`; `verticalInsets = 12.0` → `8.0`.

2c. Title always semibold: replace the `headerFont` computed property's varying logic with `.compound.bodyLGSemibold` in all cases (keep the property, one-line body, TG-SKIN comment: Telegram titles are always bold). Keep `lastMessageFont` as-is (Telegram previews are regular; Element's unread-semibold preview goes away — set it to plain `.compound.bodyMD` always).

2d. Mute icon moves beside the name: in the `header`'s left `HStack(spacing: 4)`, after the name `Text`, add:

```swift
                    if room.badges.isMuteShown {
                        CompoundIcon(\.notificationsOffSolid, size: .custom(15), relativeTo: .compound.bodyLG)
                            .foregroundColor(.compound.iconTertiary)
                    }
```

and REMOVE the mute icon from the trailing badges HStack.

2e. Badges area (trailing footer HStack): replace the dot with the pill logic —

```swift
                if room.badges.isMentionShown {
                    mentionIcon
                }
                if room.badges.unreadCount > 0 || room.badges.isDotShown {
                    TelegramUnreadBadge(count: room.badges.unreadCount, isMuted: room.badges.isMuted)
                } else if room.isFavourite {
                    // TG-SKIN: Telegram shows the pin only when no unread badge; favourites map to pins.
                    CompoundIcon(\.pin, size: .custom(15), relativeTo: .compound.bodyMD)
                        .foregroundColor(.compound.iconQuaternary)
                }
```

Keep the call badge; delete the old `Circle()` dot block. Check `\.pin` exists in CompoundIcons (grep the generated file); if absent use `\.pinSolid` or the closest pin/favourite glyph and note it.

2f. Separator: align to text start — pass a leading inset to the divider so it starts where the text starts (`horizontalInsets + 60 + 10`); read `RowDivider.swift` and either use an existing inset parameter or add a `leadingInset` parameter (TG-SKIN) defaulting to the old behavior so other callers are unaffected.

2g. Update `HomeScreenRoomCell_Previews`' mock factory so preview states exercise: unmuted count (e.g. 4), muted count (e.g. 12), marked-unread empty pill, favourite pin. Extend the existing `makeRoom`/`mockRoom` factories with the new `Badges` fields.

- [ ] **Step 3: Build + spot-run the cell-adjacent suites**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/HomeScreenRoomTests \
  -only-testing:UnitTests/HomeScreenViewModelTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Expected: TEST SUCCEEDED.

- [ ] **Step 4: Lint and commit**

```bash
swiftformat --lint . && swiftlint lint --quiet
git add ElementX/Sources/Screens/HomeScreen/View/TelegramUnreadBadge.swift ElementX/Sources/Screens/HomeScreen/View/HomeScreenRoomCell.swift ElementX/Sources/Other/Avatars.swift ElementX/Sources/Other/SwiftUI/RowDivider.swift ElementX.xcodeproj
git commit -m "Restyle the chat list row to Telegram's layout

60pt avatars, always-bold names, numeric unread pills (grey when
muted, empty for marked-unread), mute icon beside the name, favourite
pin when no badge, text-aligned separators. Metrics transcribed from
the vendored Telegram sources. TG-SKIN.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Nav bar chrome — drop the avatar button and bloom

**Files:**
- Modify: `ElementX/Sources/Screens/HomeScreen/View/HomeScreen.swift` (toolbar lines ~51-97, bloom line ~33)

**Interfaces:** consumes nothing new. `HomeScreenViewModel`'s `.showSettings` action and its test stay (harmless dormant path; deleting it would churn upstream files for nothing).

- [ ] **Step 1: Edit the toolbar**

- Delete the `.navigationBarLeading` `settingsButton` ToolbarItem AND the `settingsButton` property (TG-SKIN comment at the deletion site: settings lives in the tab bar). Keep `requiresExtraAccountSetup` badge behavior in mind: grep `requiresExtraAccountSetup` — if the avatar badge was its only surface, note in the report that the setup-needed indicator lost its home-screen surface (acceptable: the settings TAB still exposes setup prompts inside; list it in the PR body).
- Compose button: grep the generated CompoundIcons for a compose/pencil glyph (`compose`, `edit`, `pencil`); if one exists, swap `CompoundIcon(\.plus)` → that glyph (TG-SKIN: Telegram compose); otherwise keep `\.plus` and say so in the report.
- Remove `.toolbarBloom(hasSearchBar: true)` at the call site ONLY (line ~33; the Spaces screen keeps its bloom — out of Phase 3 scope). TG-SKIN comment.

- [ ] **Step 2: Verify HomeScreenViewModel tests still pass**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/HomeScreenViewModelTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Expected: TEST SUCCEEDED (the `.showSettings` VM test exercises the view model, not the deleted button).

- [ ] **Step 3: Lint and commit** (message: "Remove the home screen avatar button and bloom" + body noting settings-tab rationale + trailer).

---

### Task 4: Telegram folder-style filter tabs

**Files:**
- Modify: `ElementX/Sources/Screens/HomeScreen/View/Filters/RoomListFilterView.swift` (the `FilterToggleStyle`)
- Modify: `ElementX/Sources/Screens/HomeScreen/View/Filters/RoomListFiltersView.swift` (spacing/padding only if needed)

**Look (Telegram iOS folder tabs):** text-only labels in a horizontal row; selected = accent color text with a 3pt rounded accent underline bar directly below; unselected = `textSecondary`; no capsule background, no stroke.

- [ ] **Step 1: Restyle `FilterToggleStyle`**

Replace the chip's `RoundedRectangle` background/stroke styling with (TG-SKIN block):

```swift
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(configuration.isOn ? .compound.bodyMDSemibold : .compound.bodyMD)
            .foregroundColor(configuration.isOn ? .compound.textActionAccent : .compound.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .overlay(alignment: .bottom) {
                if configuration.isOn {
                    Capsule()
                        .fill(Color.compound.textActionAccent)
                        .frame(height: 3)
                        .padding(.horizontal, 8)
                }
            }
    }
```

Adapt to the file's actual `FilterToggleStyle` shape (it may take `isOn` differently and carry `.drawingGroup()`/`matchedGeometryEffect` — keep those mechanics; only the visual styling changes). Keep the clear button in `RoomListFiltersView` as-is.

- [ ] **Step 2: Build check** (any `-only-testing:UnitTests/HomeScreenViewModelTests` run doubles as a build gate).

- [ ] **Step 3: Lint and commit** ("Restyle room list filters as Telegram folder tabs" + trailer).

---

### Task 5: Settings pop-to-root on re-route (carried from Phase 2 review)

**Files:**
- Modify: `ElementX/Sources/FlowCoordinators/SettingsFlowCoordinator.swift` (`handleAppRoute` ~lines 59-70, `startEncryptionSettingsFlow` ~147-164)
- Test: `UnitTests/Sources/UserSessionFlowCoordinatorTests.swift`

- [ ] **Step 1: Failing test**

Add (mirroring `chatBackupSettingsRouteSelectsSettingsTab`'s scaffolding): route `.chatBackupSettings` twice, assert the settings tab's stack contains exactly ONE pushed flow's worth of screens (same `stackCoordinators` count after the second route as after the first) — the current bug stacks a second encryption flow.

- [ ] **Step 2: Verify it fails** (same UserSessionFlowCoordinatorTests command as prior phases; expect the count assertion to fail).

- [ ] **Step 3: Implement**

In `handleAppRoute`, before the `switch` (TG-SKIN comment: tab-mounted settings must reset on re-route; see docs/fork-slimming.md):

```swift
        // TG-SKIN: the settings stack is session-lived (tab root) — unwind any
        // pushed sub-screens before re-routing so repeat deep links don't stack
        // duplicate flows on zombie screens.
        navigationStackCoordinator.popToRoot(animated: false)
        encryptionSettingsFlowCoordinator = nil
```

(`presentSettingsScreen`'s `setRootCoordinator` already pops internally; this guard covers the push-based routes. Clearing the retained encryption coordinator prevents the dealloc-while-screens-remain zombie the Phase 2 review documented.)

- [ ] **Step 4: Verify pass**, **Step 5: lint + commit** ("Unwind the settings stack before re-routing deep links" + trailer).

---

### Task 6: Playbook, verification, snapshots, PR (controller-run)

**Files:** `docs/fork-slimming.md` (inventory rows); no other code.

- [ ] **Step 1: Playbook rows** — add to the TG-SKIN inventory: `HomeScreenModels.swift` (Badges.unreadCount/isMuted), `HomeScreenRoomCell.swift` (Telegram row restyle), `Avatars.swift` (60pt chats avatar, if the shared constant route was taken), `RowDivider.swift` (leadingInset param, if added), `HomeScreen.swift` (avatar button + bloom removal, compose icon), `Filters/RoomListFilterView.swift` (folder tabs), `SettingsFlowCoordinator.swift` (pop-to-root guard row update); fork-owned files list gains `TelegramUnreadBadge.swift`. Commit.
- [ ] **Step 2: Full affected-suite run** (HomeScreenRoomTests, HomeScreenViewModelTests, UserSessionFlowCoordinatorTests, TelegramThemeHookTests) — expect green.
- [ ] **Step 3: Push, open PR** (`pr-feature` label; body notes: snapshot re-record incoming via label, avatar-button removal rationale, favourite→pin mapping, swipe actions deferred to the interactions phase because none exist upstream — spec's "recolor existing swipes" premise was wrong).
- [ ] **Step 4: Apply `record-snapshots` label** → Element CI re-records and pushes a snapshots commit → approve its gated workflow runs (`gh api -X POST repos/khamitovdr/element-x-ios/actions/runs/<id>/approve`) → wait for green.
- [ ] **Step 5: Device build → install → RELAUNCH (`--terminate-existing`)** → user checklist: 60pt avatars + bold names, numeric blue pills (gray on a muted room), mute icon beside names, pin on a favourite room with no unreads, filter tabs underline style, no avatar button top-left, no bloom gradient.
- [ ] **Step 6: Final whole-branch review (most capable model), fix loop, then merge on CI green + user device verification; sync develop; archive ledger.**
