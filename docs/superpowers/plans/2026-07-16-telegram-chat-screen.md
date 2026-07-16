# Telegram Chat Screen (Phase 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The chat screen looks like Telegram Day/Night: bubbles with 16/8 merged corners and a tail on the last message of a group, blue screen-anchored gradient outgoing bubbles with light content, flat `0xF1F1F4`/`0x1D1D1D` incoming bubbles, Telegram reaction pills, a white composer field, and a centered room header with trailing avatar.

**Architecture:** A fork-owned `TelegramBubbleShape` replaces the fixed-12pt `cornerRadius` call in `TimelineItemBubbleBackground` (the group-aware corner selection already exists — we change radii and add the tail). Outgoing content gets Telegram's light-on-blue look via a one-line forced dark `colorScheme` on bubble content (every Compound dynamic color — text, timestamps, attributed strings — resolves to its dark variant at render time, no per-view color surgery). The `_bgBubble*` "awaiting" tokens in the in-tree Compound copy get Telegram values; the outgoing gradient is a fork-owned screen-anchored `LinearGradient` view. Geometry truth: `docs/superpowers/specs/2026-07-16-telegram-bubble-reference.md`.

**Tech Stack:** Swift 6.2, SwiftUI (`Shape`, `GeometryReader`), Compound tokens, Swift Testing, XcodeGen (two new files), PreviewTests re-record via `record-snapshots` label.

## Global Constraints

- Branch: `feature/telegram-chat-screen` (exists, cut from develop 4e5c5c2a2).
- **Never push or PR to upstream `element-hq`**; all `gh` commands take `--repo khamitovdr/element-x-ios`.
- `xcodebuild` prefix `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; simulator tests add `CODE_SIGNING_ALLOWED=NO`; simulator "iPhone 17"; plain simulator `build` is broken — use `test`/`build-for-testing`.
- Tasks 1 and 2 each create ONE new file → run `xcodegen` and commit `ElementX.xcodeproj` in those tasks only.
- Pre-commit hook runs SwiftFormat and aborts after auto-fixing — re-stage, re-commit.
- Every upstream-file edit carries a `TG-SKIN` marker; new fork-owned files use the SPDX header WITH trailing period; Task 7 adds inventory rows.
- App/UnitTests default to MainActor; **any closure UIKit calls off-main must be `nonisolated`** (the `UIColor { … }` dynamic providers added to Compound tokens in Task 2 are inside the nonisolated-by-default compound-ios package — verify that package has no MainActor default before assuming; if its closures land MainActor-isolated, apply the `nonisolated` lesson from Phase 1).
- No new user-visible strings. Do NOT re-record snapshots locally (CI label flow only, Task 7).
- Scope deviations from the spec, already adjudicated: NO wallpaper view (the approved "Day" variant uses a plain background in Telegram itself — the themed canvas already matches; Night gradient wallpaper = future polish). Read receipts stay below the bubble (Matrix-specific feature, styled not restructured).
- Telegram reference values live in `docs/superpowers/specs/2026-07-16-telegram-bubble-reference.md` (geometry) and `...telegram-palette-reference.md` §D (colors). Key numbers: corners 16/8; tail on `.single`/`.last` only, ~6pt overhang × 17pt tall, concave upper edge; text insets 11h/6v; merged vertical spacing 0, unmerged 2; outgoing Day gradient `[0x57B2E0 → 0x0088FF]` top→bottom SCREEN-anchored, Night `[0x61BCF9 → 0x0088FF]`; incoming Day `0xF1F1F4` / Night `0x1D1D1D`, no stroke.

---

### Task 1: TelegramBubbleShape + bubble background integration

**Files:**
- Create: `ElementX/Sources/Screens/Timeline/View/Style/TelegramBubbleShape.swift`
- Modify: `ElementX/Sources/Screens/Timeline/View/Style/TimelineItemBubbleBackground.swift:37-69`
- Modify: `ElementX/Sources/Screens/Timeline/View/Style/TimelineItemBubbledStylerView.swift` (bubble insets ~271-297 text case → 11h/6v; `messageBubbleTopPadding` ~240-243 → 2 where no sender header is shown)
- Test: `UnitTests/Sources/TelegramBubbleShapeTests.swift` (new — same xcodegen run)

**Interfaces:**
- Consumes: existing `TimelineGroupStyle` (`.single/.first/.middle/.last`, `TimelineStyle.swift:12`), env `\.timelineGroupStyle`, the modifier's existing `isOutgoing`.
- Produces: `struct TelegramBubbleShape: Shape { let groupStyle: TimelineGroupStyle; let isOutgoing: Bool }` with `var hasTail: Bool`. Task 2 fills this same shape with the gradient.

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/TelegramBubbleShapeTests.swift`:

```swift
@testable import ElementX

import SwiftUI
import Testing

struct TelegramBubbleShapeTests {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 60)
    
    @Test
    func tailOnlyOnLastAndSingle() {
        #expect(TelegramBubbleShape(groupStyle: .single, isOutgoing: true).hasTail)
        #expect(TelegramBubbleShape(groupStyle: .last, isOutgoing: true).hasTail)
        #expect(!TelegramBubbleShape(groupStyle: .first, isOutgoing: true).hasTail)
        #expect(!TelegramBubbleShape(groupStyle: .middle, isOutgoing: true).hasTail)
    }
    
    @Test
    func tailExtendsBeyondBodyOnTheCorrectSide() {
        let outgoing = TelegramBubbleShape(groupStyle: .last, isOutgoing: true).path(in: rect)
        #expect(outgoing.boundingRect.maxX > rect.maxX)
        #expect(outgoing.boundingRect.minX == rect.minX)
        
        let incoming = TelegramBubbleShape(groupStyle: .last, isOutgoing: false).path(in: rect)
        #expect(incoming.boundingRect.minX < rect.minX)
        #expect(incoming.boundingRect.maxX == rect.maxX)
        
        let middle = TelegramBubbleShape(groupStyle: .middle, isOutgoing: true).path(in: rect)
        #expect(middle.boundingRect == rect)
    }
    
    @Test
    func mergedCornersAreTighter() {
        // A point 3pt inside the top-trailing corner: outside a 16pt arc, inside an 8pt arc.
        let probe = CGPoint(x: rect.maxX - 3, y: rect.minY + 3)
        #expect(!TelegramBubbleShape(groupStyle: .single, isOutgoing: true).path(in: rect).contains(probe))
        #expect(TelegramBubbleShape(groupStyle: .middle, isOutgoing: true).path(in: rect).contains(probe))
        // Leading corners never merge: mirrored probe stays outside for both.
        let leadingProbe = CGPoint(x: rect.minX + 3, y: rect.minY + 3)
        #expect(!TelegramBubbleShape(groupStyle: .middle, isOutgoing: true).path(in: rect).contains(leadingProbe))
    }
}
```

- [ ] **Step 2: xcodegen + run to verify failure**

```bash
cd /Users/khamit/element_x_ios_fork && xcodegen
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/TelegramBubbleShapeTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -8
```

Expected: BUILD FAILED (`TelegramBubbleShape` unknown).

- [ ] **Step 3: Implement the shape**

`ElementX/Sources/Screens/Timeline/View/Style/TelegramBubbleShape.swift` (SPDX header with trailing period):

```swift
import SwiftUI

/// Telegram's message bubble: 16pt corners, 8pt on the tail-side corners that touch a
/// grouped neighbour, and a ~6×17pt tail on the last message of a group. Geometry
/// transcribed from ChatMessageBubbleImages.swift — see
/// docs/superpowers/specs/2026-07-16-telegram-bubble-reference.md. TG-SKIN (fork-owned).
struct TelegramBubbleShape: Shape {
    let groupStyle: TimelineGroupStyle
    let isOutgoing: Bool
    
    private static let maxRadius: CGFloat = 16
    private static let minRadius: CGFloat = 8
    private static let tailWidth: CGFloat = 6
    private static let tailHeight: CGFloat = 17
    
    var hasTail: Bool { groupStyle == .single || groupStyle == .last }
    
    func path(in rect: CGRect) -> Path {
        // Radii in tail-side terms, then mapped to left/right. Tail side never reduces
        // its bottom corner when the tail is present.
        let (tailTop, tailBottom): (CGFloat, CGFloat) = switch groupStyle {
        case .single: (Self.maxRadius, Self.maxRadius)
        case .first: (Self.maxRadius, Self.minRadius)
        case .middle: (Self.minRadius, Self.minRadius)
        case .last: (Self.minRadius, Self.maxRadius)
        }
        
        let (topLeft, topRight, bottomLeft, bottomRight) = isOutgoing
            ? (Self.maxRadius, tailTop, Self.maxRadius, tailBottom)
            : (tailTop, Self.maxRadius, tailBottom, Self.maxRadius)
        
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight), radius: topRight,
                    startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight), radius: bottomRight,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft), radius: bottomLeft,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft), radius: topLeft,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        
        if hasTail {
            path.addPath(tailPath(in: rect))
        }
        return path
    }
    
    /// The lens-shaped tail hugging the bottom tail-side corner: sweeps along the bottom
    /// edge past the body, returns up the side with a concave curve (the reference's
    /// carved-ellipse notch, approximated with a quad curve).
    private func tailPath(in rect: CGRect) -> Path {
        var path = Path()
        if isOutgoing {
            path.move(to: CGPoint(x: rect.maxX - Self.maxRadius, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX + Self.tailWidth, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - Self.tailHeight),
                              control: CGPoint(x: rect.maxX + 1, y: rect.maxY - 6))
            path.addLine(to: CGPoint(x: rect.maxX - Self.maxRadius, y: rect.maxY - Self.tailHeight))
        } else {
            path.move(to: CGPoint(x: rect.minX + Self.maxRadius, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX - Self.tailWidth, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - Self.tailHeight),
                              control: CGPoint(x: rect.minX - 1, y: rect.maxY - 6))
            path.addLine(to: CGPoint(x: rect.minX + Self.maxRadius, y: rect.maxY - Self.tailHeight))
        }
        path.closeSubpath()
        return path
    }
}
```

Add a `PreviewProvider` + `TestablePreview` in the same file showing all four group styles × incoming/outgoing (fills in `_bgBubbleIncoming`), so the tail silhouette gets snapshot coverage.

- [ ] **Step 4: Integrate in `TimelineItemBubbleBackground`**

Replace the `cornerRadius(12, corners:)` + `RoundedCornerShape` overlay (lines 37-69) with (TG-SKIN):

```swift
    func body(content: Content) -> some View {
        let shape = TelegramBubbleShape(groupStyle: timelineGroupStyle, isOutgoing: isOutgoing)
        content
            .padding(insets)
            .background { shape.fill(color ?? .clear) }
            .overlay {
                if let borderColor {
                    shape.stroke(borderColor)
                }
            }
    }
```

Delete the now-unused `roundedCorners` computed property. The tail draws outside the content bounds by design (backgrounds don't clip). Media corner radii (`contentCornerRadius` in the styler) change from 12-based to `16 - 1 = 15` where they mirror the bubble radius — read that property and adjust its constant with a TG-SKIN comment.

- [ ] **Step 5: Insets + spacing in the styler**

- Text `bubbleInsets` → horizontal 11, vertical 6 (find the text case in the `bubbleInsets` extension ~271-297; TG-SKIN comment citing the reference doc).
- `messageBubbleTopPadding` (~240-243): keep 8 when a sender header shows above (incoming group chats, `.single`/`.first`); use 2 for outgoing/DM `.single`/`.first` (Telegram's unmerged gap). Merged positions stay 0.

- [ ] **Step 6: Run tests + build gate**

Shape tests + `-only-testing:UnitTests/TimelineViewModelTests` (builds the timeline stack). Expected: TEST SUCCEEDED.

- [ ] **Step 7: Lint and commit** (`git add` the two new/changed Style files, the test file, and `ElementX.xcodeproj`; message "Give message bubbles Telegram's shape and tail" + body + `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`).

---

### Task 2: Bubble colors — tokens, screen-anchored gradient, light-on-blue content

**Files:**
- Modify: `compound-ios/Sources/Compound/Colors/CompoundColors.swift:78-82` (`_bgBubbleIncoming`, `_bgBubbleOutgoing`) and the matching UIColor definitions if present in `CompoundUIColors.swift`
- Create: `ElementX/Sources/Screens/Timeline/View/Style/TelegramBubbleGradient.swift`
- Modify: `ElementX/Sources/Screens/Timeline/View/Style/TimelineItemBubbleBackground.swift` (fill outgoing with the gradient)
- Modify: `ElementX/Sources/Screens/Timeline/View/Style/TimelineItemBubbledStylerView.swift` (force dark colorScheme on outgoing bubble content; drop the default border for the restyled bubbles if `borderColor` was supplying one)
- Test: shape/preview coverage from Task 1 re-used; token values asserted in `UnitTests/Sources/TelegramThemeHookTests.swift`-style resolved checks added to `UnitTests/Sources/TelegramBubbleShapeTests.swift`'s file (new suite `TelegramBubbleColorTests`)

**Interfaces:**
- Consumes: `TelegramBubbleShape` (Task 1), `TelegramPalette.Chat.outgoingBubbleGradientDay/Night` + `incomingBubbleDay/Night` (exist since Phase 0).
- Produces: `struct TelegramBubbleGradient: View` (fills its container with the screen-anchored slice); `_bgBubble*` tokens carrying Telegram values.

- [ ] **Step 1: Failing color test**

```swift
struct TelegramBubbleColorTests {
    @Test
    func bubbleTokensCarryTelegramValues() {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let incoming = UIColor(Color.compound._bgBubbleIncoming)
        #expect(incoming.resolvedColor(with: light).hexString == "#F1F1F4")
        #expect(incoming.resolvedColor(with: dark).hexString == "#1D1D1D")
        let outgoing = UIColor(Color.compound._bgBubbleOutgoing)
        #expect(outgoing.resolvedColor(with: light).hexString == "#2B9DEF") // gradient midpoint, derived
        #expect(outgoing.resolvedColor(with: dark).hexString == "#30A2FC") // gradient midpoint, derived
    }
}
```

(`hexString` helper exists in `UnitTests/Sources/UIColor+TestHex.swift`.) Run — expect FAIL on current gray values.

- [ ] **Step 2: Token values**

In `compound-ios/.../CompoundColors.swift` (TG-SKIN block; compound-ios has NO MainActor default so the closures are already nonisolated — verify with one look at its Package.swift swiftSettings and note in the report):

```swift
    // TG-SKIN: Telegram bubble colours (see telegram-palette-reference §D). The outgoing
    // flat token is the gradient midpoint — media/placeholder consumers use it; the real
    // bubble fill is the screen-anchored gradient in TelegramBubbleGradient.
    public let _bgBubbleIncoming = Color(UIColor { $0.isLight ? UIColor(red: 241 / 255, green: 241 / 255, blue: 244 / 255, alpha: 1) : UIColor(red: 29 / 255, green: 29 / 255, blue: 29 / 255, alpha: 1) })
    public let _bgBubbleOutgoing = Color(UIColor { $0.isLight ? UIColor(red: 43 / 255, green: 157 / 255, blue: 239 / 255, alpha: 1) : UIColor(red: 48 / 255, green: 162 / 255, blue: 252 / 255, alpha: 1) })
```

Keep the `@available(iOS, deprecated: 100000.0, ...)` attributes as-is. Mirror in `CompoundUIColors.swift` ONLY if `_bgBubble*` exist there (Phase 1 research says they don't — verify with grep).

- [ ] **Step 3: Screen-anchored gradient view**

`ElementX/Sources/Screens/Timeline/View/Style/TelegramBubbleGradient.swift` (fork-owned, SPDX header with trailing period):

```swift
import SwiftUI

/// Telegram's outgoing-bubble gradient is anchored to the SCREEN, not the bubble: the
/// [top → bottom] colours span the visible viewport and each bubble shows the slice at
/// its on-screen position, shifting as you scroll (WallpaperBackgroundNode.contentsRect
/// behaviour — see the bubble reference doc). TG-SKIN (fork-owned).
struct TelegramBubbleGradient: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            let screenHeight = max(UIScreen.main.bounds.height, 1)
            let colors = colorScheme == .dark
                ? TelegramPalette.Chat.outgoingBubbleGradientNight
                : TelegramPalette.Chat.outgoingBubbleGradientDay
            LinearGradient(colors: colors.map { Color(TelegramPalette.rgb($0)) },
                           startPoint: UnitPoint(x: 0.5, y: -frame.minY / max(frame.height, 1)),
                           endPoint: UnitPoint(x: 0.5, y: (screenHeight - frame.minY) / max(frame.height, 1)))
        }
    }
}
```

(Extending the gradient's unit points beyond 0...1 renders exactly the viewport slice this bubble occupies. `TelegramPalette` is nonisolated since Phase 1.)

- [ ] **Step 4: Fill outgoing bubbles with it**

In `TimelineItemBubbleBackground`, replace the plain fill for the default outgoing case (TG-SKIN):

```swift
            .background {
                if isOutgoing, usesDefaultBubbleColor {
                    shape.fill(.clear).background(TelegramBubbleGradient().clipShape(shape))
                } else {
                    shape.fill(color ?? .clear)
                }
            }
```

`usesDefaultBubbleColor` needs a way to distinguish "default bubble" from item-specific overrides — read `bubbleBackgroundColor` in the styler (line ~254): the cleanest route is passing an explicit `isDefaultOutgoing: Bool` (or optional `fillStyle` enum) through the `.bubbleBackground(...)` modifier from the styler where the default-vs-custom decision already lives. Choose the smallest-diff mechanism and document it. IMPORTANT: the tail must be part of the clipped gradient (clipShape(shape) covers it since the shape includes the tail).

- [ ] **Step 5: Light content on outgoing bubbles**

In `TimelineItemBubbledStylerView.messageBubble` (~196-206), apply to the bubble content only (TG-SKIN):

```swift
            .environment(\.colorScheme, timelineItem.isOutgoing && colorScheme == .light ? .dark : colorScheme)
```

(One line: in light mode, outgoing content renders with dark-variant tokens — white primary text, light-gray secondary, and every attributed-string colour flips at render time because Compound colours are dynamic providers. In dark mode content is already light.) Add `@Environment(\.colorScheme) private var colorScheme` to the styler. Known accepted quirk to note in the report: links inside outgoing bubbles render dark-accent blue-on-blue — acceptable first pass, ledger it for polish.

- [ ] **Step 6: Run tests** (color suite + shape suite + TimelineViewModelTests build gate) — green.

- [ ] **Step 7: xcodegen already ran? NO — this task added `TelegramBubbleGradient.swift`: run `xcodegen`, stage `ElementX.xcodeproj` too. Lint and commit** ("Paint bubbles with Telegram's colours and screen-anchored gradient").

---

### Task 3: Send info — inline delivery tick, Telegram styling

**Files:**
- Modify: `ElementX/Sources/Screens/Timeline/View/Style/TimelineItemSendInfoLabel.swift`
- Modify: `ElementX/Sources/Screens/Timeline/View/Supplementary/TimelineItemStatusView.swift` (suppress the below-bubble delivery badge; read receipts stay)
- Modify: `ElementX/Sources/Screens/Timeline/View/Style/TimelineItemBubbledStylerView.swift` (pass delivery status into the send info if not already available there)

**Interfaces:** consumes `timelineItem.properties.deliveryStatus` (existing) and the existing `statusIcon` slot in `TimelineItemSendInfoLabel`.

- [ ] **Step 1:** Read `TimelineItemSendInfoLabel.swift:58-149` fully. Extend the label so outgoing items append a delivery tick after the timestamp: single check while `.sending`→`.sent` (use the existing Compound check icons the delivery badge uses — read `TimelineDeliveryStatusView` for the exact keypaths), sized `.xSmall`, same foreground as the timestamp. The timestamp font stays `bodyXS`; colours already flip on outgoing via Task 2's colorScheme trick — do NOT hardcode white.
- [ ] **Step 2:** In `TimelineItemStatusView`, return `EmptyView` for the pure delivery-status case when the item is outgoing (the tick now lives inline); keep the read-receipts branch untouched. TG-SKIN comments both sides.
- [ ] **Step 3:** Build gate + `-only-testing:UnitTests/TimelineViewModelTests`; lint; commit ("Move the delivery tick into the bubble, Telegram-style").

---

### Task 4: Reaction pills

**Files:**
- Modify: `ElementX/Sources/Screens/Timeline/View/Supplementary/TimelineReactionsView.swift:99-122` (`TimelineReactionButtonLabel`), content paddings ~175-193

- [ ] **Step 1:** Restyle chips to Telegram pills (TG-SKIN): shape `Capsule()`; unselected = `bgAccentSubtle` fill, `textActionAccent` count text; selected (`isHighlighted`) = `bgAccentRest` fill, `textOnSolidPrimary` count; DELETE the 2pt `bgCanvasDefault` outer cutout stroke and the `borderInteractivePrimary` overlay; padding vertical 4, horizontal 10; count font `bodySM`, emoji `bodySM` (Telegram pills are tighter than Element chips). Keep `CollapsibleReactionLayout` mechanics and the add-more button (recolor its background to `bgAccentSubtle`, icon `textActionAccent`).
- [ ] **Step 2:** Build gate; lint; commit ("Restyle reactions as Telegram pills").

---

### Task 5: Composer skin

**Files:**
- Modify: `ElementX/Sources/Screens/RoomScreen/ComposerToolbar/View/MessageComposer.swift:204-246` (`MessageComposerStyleModifier`, iOS ≤18 branch)
- Modify: `ElementX/Sources/Screens/RoomScreen/ComposerToolbar/View/RoomAttachmentPicker.swift:22-25` (icon)

- [ ] **Step 1:** In the iOS ≤18 branch of the composer style: fill `bgCanvasDefault` (white/black — Telegram's field) instead of `bgSubtleSecondary`; stroke stays `borderInteractiveSecondary` at 0.5 (already Telegram-gray via the theme). Leave the iOS 26 glass branch untouched (TG-SKIN comments). Corner radius 21 stays (Telegram's field is a comparable capsule).
- [ ] **Step 2:** Attach button icon: grep the generated CompoundIcons for `attachment`/`paperclip`; if a paperclip-like glyph exists swap `\.plus` → it (TG-SKIN: Telegram attach), else keep `\.plus` with report evidence (same protocol as Phase 3's compose icon).
- [ ] **Step 3:** Build gate (`-only-testing:UnitTests/ComposerToolbarViewModelTests` if that suite exists — check; otherwise TimelineViewModelTests); lint; commit ("Skin the composer field Telegram-style").

---

### Task 6: Centered room header with trailing avatar

**Files:**
- Modify: `ElementX/Sources/Other/SwiftUI/Views/RoomHeaderView.swift:29-96`
- Modify: `ElementX/Sources/Screens/RoomScreen/View/RoomScreen.swift:293-328` (toolbar builder) and `:121` (`toolbarRole`)

- [ ] **Step 1:** `RoomHeaderView.content`: center the name+subtitle `VStack` (Telegram: title `bodyMDSemibold` centered, subtitle below in `bodyXS`/`textSecondary` — both already the current fonts; remove the leading avatar from this HStack). `body`: drop the leading-alignment `frame`/`toolbarRole(.editor)` special-casing so the principal item centers naturally (TG-SKIN; keep the whole header tappable → `.displayRoomDetails`).
- [ ] **Step 2:** In `RoomScreen`'s toolbar builder add the avatar as the LAST trailing item (after call controls): a `ToolbarItem(placement: .primaryAction)` whose content is the same `RoomAvatarImage` (size `.room(on: .timeline)`) wrapped in a Button sending the same details action. TG-SKIN.
- [ ] **Step 3:** Build gate; lint; commit ("Center the room header and move the avatar trailing, Telegram-style").

---

### Task 7: Playbook, verification, snapshots, PR (controller-run)

- [ ] **Step 1:** `docs/fork-slimming.md` inventory rows: `TimelineItemBubbleBackground.swift` (TelegramBubbleShape integration), `TimelineItemBubbledStylerView.swift` (insets/spacing/colorScheme flip/gradient wiring), `compound-ios/.../CompoundColors.swift` row extended (`_bgBubble*` Telegram values), `TimelineItemSendInfoLabel.swift` + `TimelineItemStatusView.swift` (inline tick), `TimelineReactionsView.swift` (pills), `MessageComposer.swift` + `RoomAttachmentPicker.swift` (composer skin), `RoomHeaderView.swift` + `RoomScreen.swift` (header); fork-owned list gains `TelegramBubbleShape.swift`, `TelegramBubbleGradient.swift`. Commit.
- [ ] **Step 2:** Full affected suites: `TelegramBubbleShapeTests`, `TelegramBubbleColorTests`, `TimelineViewModelTests`, `TelegramThemeHookTests` — green.
- [ ] **Step 3:** Push; open PR (`pr-feature`; body: scope deviations [no wallpaper — Day variant is plain; receipts stay below], link both reference docs, the ~40-preview snapshot blast radius, blue-on-blue link polish item); apply `record-snapshots` label AFTER the final push of code (Phase 3 lesson: label events snapshot the PR head at event time).
- [ ] **Step 4:** Dispatch final whole-branch review (most capable model) in parallel with the device build; fix loop as needed (fixes → push → RE-trigger record-snapshots by remove/re-add label).
- [ ] **Step 5:** Approve Element CI's gated runs after the snapshots commit; watch CI via a Monitor poll loop (not `gh --watch` — the environment kills long watchers).
- [ ] **Step 6:** Device build → install → RELAUNCH (`--terminate-existing`); user checklist: bubbles with tails on last-of-group, tight merged corners, blue gradient outgoing that shifts as you scroll, white text in outgoing bubbles, gray F1F1F4 incoming, timestamp+tick inside the bubble, Telegram reaction pills, white composer field, centered room title with avatar on the right.
- [ ] **Step 7:** Merge on CI green + user device verification; sync develop; archive ledger; update project memory.
