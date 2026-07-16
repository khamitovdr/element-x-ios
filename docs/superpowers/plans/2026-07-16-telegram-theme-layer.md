# Telegram Theme Layer (Phases 0–1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-skin every screen's colors to Telegram's Day (light) / Night (dark) palette via a fork-owned startup hook, with zero upstream edits except one small marked change in `compound-ios`.

**Architecture:** A fork-owned `TelegramThemeHook: CompoundHookProtocol` overrides Compound's semantic color tokens at app startup. Upstream already calls `appHooks.compoundHook.override(colors: Color.compound, uiColors: UIColor.compound)` in `AppCoordinator.init` (line ~76) *before any UI is built* — we only register our hook in the fork-owned `AppHooks+Fork.setUp()`. Raw Telegram values live in `TelegramPalette.swift`; the Compound-token mapping lives in the hook. One marked edit in `compound-ios` makes avatar/sender "decorative" colors override-aware.

**Tech Stack:** Swift 6.2, SwiftUI/UIKit, Compound design system (vendored `compound-ios` + `CompoundDesignTokens` SPM package), Swift Testing (`@Suite`/`@Test`/`#expect`), XcodeGen, Sourcery (untouched here).

## Global Constraints

- Work on branch `feature/telegram-skin` (already exists, holds the spec commits).
- **Never push or PR to upstream `element-hq`** — all `gh` commands need `--repo khamitovdr/element-x-ios`.
- `xcodebuild` needs prefix `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (machine's active dev dir is CommandLineTools).
- After creating new files, run `xcodegen` from repo root to regenerate the project, otherwise Xcode won't see them.
- Simulator: plain `xcodebuild build` fails on a pre-existing BuildExtensions error — use `build-for-testing` / `test` for simulator destinations. Device builds work with plain `build`. Simulator is "iPhone 17".
- Git hooks may not be installed: run `swiftformat --lint .` and `swiftlint lint` manually before each commit; fix reported issues, don't bypass.
- App + UnitTests targets build with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — do NOT add redundant `@MainActor`.
- Comments: only where code hides a trap or a choice needs justifying; one line where possible.
- Every in-place edit of an upstream-owned file carries a `TG-SKIN` comment marker.
- Commit messages need a title + body, ending with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- No new user-facing strings in this plan (no Localazy work needed).
- Reference truth for all hex values: `docs/superpowers/specs/2026-07-16-telegram-palette-reference.md` (committed). Values marked `derived:` in code are Neutrino-invented interpolations (Telegram has no equivalent token) — keep the `derived:` comment so future tuning knows they're fair game.
- Deliberate deviation from the spec's Phase 0 wording: bubble *geometry* (corner radii, tail path from `ChatMessageBubbleImages.swift`) is NOT transcribed here — it has no consumer until Phase 4, whose plan will transcribe it next to its `TelegramBubbleShape`. All Phase 0 *color* transcription is complete (palette reference doc + `TelegramPalette`).

---

### Task 1: TelegramPalette — raw values + helpers

**Files:**
- Create: `ElementX/Sources/AppHooks/Hooks/TelegramPalette.swift`
- Create: `UnitTests/Sources/UIColor+TestHex.swift` (shared test helper)
- Test: `UnitTests/Sources/TelegramPaletteTests.swift`

**Interfaces:**
- Consumes: nothing (leaf).
- Produces (used by Task 3 and later phases):
  - `enum TelegramPalette` with `static func rgb(_ rgb: UInt32, alpha: CGFloat = 1) -> UIColor`
  - `static func dynamic(day: UInt32, dayAlpha: CGFloat = 1, night: UInt32, nightAlpha: CGFloat = 1) -> UIColor`
  - `static let peerNameColors: [UInt32]` (7 entries, Telegram key order 0–6)
  - Nested `enum Chat`, `enum Avatar`, `enum Wallpaper` reference constants (consumed by Phases 4–5, inert now).
  - Test helper: `UIColor.hexString: String` ("#RRGGBB" of sRGB components) and `UIColor.alphaValue: CGFloat`.

- [ ] **Step 1: Write the failing test**

Create `UnitTests/Sources/UIColor+TestHex.swift`:

```swift
//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import UIKit

extension UIColor {
    /// "#RRGGBB" of the receiver's sRGB components, ignoring alpha.
    var hexString: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int(round(red * 255)), Int(round(green * 255)), Int(round(blue * 255)))
    }
    
    var alphaValue: CGFloat {
        cgColor.alpha
    }
}
```

Create `UnitTests/Sources/TelegramPaletteTests.swift`:

```swift
//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX

import Testing
import UIKit

@Suite
struct TelegramPaletteTests {
    @Test
    func rgbProducesExpectedComponents() {
        #expect(TelegramPalette.rgb(0x0088FF).hexString == "#0088FF")
        #expect(TelegramPalette.rgb(0x0088FF).alphaValue == 1.0)
    }
    
    @Test
    func rgbAppliesAlpha() {
        let color = TelegramPalette.rgb(0x545458, alpha: 0.55)
        #expect(color.hexString == "#545458")
        #expect(abs(color.alphaValue - 0.55) < 0.001)
    }
    
    @Test
    func dynamicResolvesPerTraitCollection() {
        let color = TelegramPalette.dynamic(day: 0xFFFFFF, night: 0x000000)
        #expect(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).hexString == "#FFFFFF")
        #expect(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).hexString == "#000000")
    }
    
    @Test
    func peerNameColorsMatchTelegramKeyOrder() {
        #expect(TelegramPalette.peerNameColors.count == 7)
        #expect(TelegramPalette.peerNameColors[5] == 0x368AD1) // key 5 = blue, Telegram's fallback
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/khamit/element_x_ios_fork && xcodegen
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/TelegramPaletteTests 2>&1 | tail -20
```

Expected: **BUILD FAILED** — `cannot find 'TelegramPalette' in scope`.
(If the `UnitTests` scheme has no testable target configured, fall back to `-scheme ElementX` with the same `-only-testing` filter.)

- [ ] **Step 3: Write the implementation**

Create `ElementX/Sources/AppHooks/Hooks/TelegramPalette.swift`:

```swift
//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import UIKit

/// Fork customisation: exact colour values transcribed from the vendored Telegram-iOS
/// sources. Do not tweak values here without updating the transcription reference:
/// docs/superpowers/specs/2026-07-16-telegram-palette-reference.md
/// "Day" is Telegram's blue-gradient light variant; "Night" is the true-black theme
/// with the stock blue accent (0x3E88F7) from defaultDarkColorPresentationTheme.
enum TelegramPalette {
    static func rgb(_ rgb: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: alpha)
    }
    
    static func dynamic(day: UInt32, dayAlpha: CGFloat = 1, night: UInt32, nightAlpha: CGFloat = 1) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? rgb(night, alpha: nightAlpha) : rgb(day, alpha: dayAlpha)
        }
    }
    
    /// PeerNameColors.defaultSingleColors, Telegram key order 0–6 (fallback key is 5, blue).
    static let peerNameColors: [UInt32] = [0xCC5049, 0xD67722, 0x955CDB, 0x40A920, 0x309EBA, 0x368AD1, 0xC7508B]
    
    // MARK: - Reference constants for later phases (chat screen, avatars, wallpaper).
    
    /// chat.message + chat.inputPanel values. Day = blue-gradient variant (user-approved);
    /// DayClassic bubbles recorded in the reference doc if we ever switch.
    enum Chat {
        static let outgoingBubbleGradientDay: [UInt32] = [0x57B2E0, 0x0088FF] // messageDay outgoing fill, top→bottom
        static let outgoingBubbleGradientNight: [UInt32] = [0x61BCF9, 0x0088FF] // night outgoing fill
        static let incomingBubbleDay: UInt32 = 0xF1F1F4 // messageDay incoming fill (no wallpaper)
        static let incomingBubbleNight: UInt32 = 0x1D1D1D // night incoming fill (drawn at 0.9 alpha)
        static let outgoingTextDay: UInt32 = 0xFFFFFF // messageDay outgoing primaryTextColor
        static let inputPanelBackgroundDay: UInt32 = 0xF2F2F2 // inputPanel.panelBackgroundColor (0.9 alpha)
        static let inputPanelBackgroundNight: UInt32 = 0x1D1D1D // inputPanel.panelBackgroundColor (0.9 alpha)
        static let inputFieldStrokeDay: UInt32 = 0x000000 // inputPanel.inputStrokeColor (0.1 alpha)
        static let inputFieldStrokeNight: UInt32 = 0xFFFFFF // inputPanel.inputStrokeColor (0.1 alpha)
    }
    
    /// AvatarNode.gradientColors, top→bottom pairs, index = peer id % 7. Initials are white.
    enum Avatar {
        static let gradients: [[UInt32]] = [
            [0xFF516A, 0xFF885E], // red
            [0xFFA85C, 0xFFCD6A], // orange
            [0x665FFF, 0x82B1FF], // violet
            [0x54CB68, 0xA0DE7E], // green
            [0x4ACCCD, 0x00FCFD], // cyan
            [0x2A9EF1, 0x72D5FD], // blue
            [0xD669ED, 0xE0A2F3] // pink
        ]
    }
    
    /// Built-in default wallpaper: pattern slug + underlying gradients.
    enum Wallpaper {
        static let patternSlug = "fqv01SQemVIBAAAApND8LDRUhRU"
        static let dayClassicGradient: [UInt32] = [0xDBDDBB, 0x6BA587, 0xD5D88D, 0x88B884] // intensity 50
        static let nightGradient: [UInt32] = [0x598BF6, 0x7A5EEF, 0xD67CFF, 0xF38B58] // intensity -34
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Same command as Step 2. Expected: **TEST SUCCEEDED**, 4 tests pass.

- [ ] **Step 5: Lint and commit**

```bash
cd /Users/khamit/element_x_ios_fork && swiftformat --lint . && swiftlint lint --quiet
git add ElementX/Sources/AppHooks/Hooks/TelegramPalette.swift UnitTests/Sources/TelegramPaletteTests.swift UnitTests/Sources/UIColor+TestHex.swift
git commit -m "Add TelegramPalette with transcribed Telegram colour values

Raw Day/Night values transcribed from the vendored Telegram-iOS sources
(see docs/superpowers/specs/2026-07-16-telegram-palette-reference.md),
plus rgb/dynamic UIColor helpers and reference constants for later
skin phases.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Make Compound's decorative colors override-aware

**Files:**
- Modify: `compound-ios/Sources/Compound/Colors/CompoundColors.swift:49-67` (init + `decorativeColors`)
- Test: `UnitTests/Sources/DecorativeColorOverrideTests.swift`

**Interfaces:**
- Consumes: existing `CompoundColors.override(_:with:)` keypath mechanism.
- Produces: `Color.compound.decorativeColor(for:)` now reflects runtime overrides of `bgDecorative1…6` / `textDecorative1…6` (behavioral change only, no API change). Task 3's decorative overrides depend on this.

**Why:** every avatar/sender-color consumer goes through `decorativeColor(for:)`, which reads an array captured once in `init` — before any hook can run. Without this change, token overrides never reach avatars or sender names.

- [ ] **Step 1: Write the failing test**

Create `UnitTests/Sources/DecorativeColorOverrideTests.swift`:

```swift
//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI
import Testing

@Suite
struct DecorativeColorOverrideTests {
    @Test
    func decorativeColorsReflectRuntimeOverrides() {
        // All six pairs get the same override so the assertion is independent
        // of which index the contentID hashes to.
        Color.compound.override(\.bgDecorative1, with: .red)
        Color.compound.override(\.bgDecorative2, with: .red)
        Color.compound.override(\.bgDecorative3, with: .red)
        Color.compound.override(\.bgDecorative4, with: .red)
        Color.compound.override(\.bgDecorative5, with: .red)
        Color.compound.override(\.bgDecorative6, with: .red)
        Color.compound.override(\.textDecorative1, with: .blue)
        Color.compound.override(\.textDecorative2, with: .blue)
        Color.compound.override(\.textDecorative3, with: .blue)
        Color.compound.override(\.textDecorative4, with: .blue)
        Color.compound.override(\.textDecorative5, with: .blue)
        Color.compound.override(\.textDecorative6, with: .blue)
        defer {
            Color.compound.override(\.bgDecorative1, with: nil)
            Color.compound.override(\.bgDecorative2, with: nil)
            Color.compound.override(\.bgDecorative3, with: nil)
            Color.compound.override(\.bgDecorative4, with: nil)
            Color.compound.override(\.bgDecorative5, with: nil)
            Color.compound.override(\.bgDecorative6, with: nil)
            Color.compound.override(\.textDecorative1, with: nil)
            Color.compound.override(\.textDecorative2, with: nil)
            Color.compound.override(\.textDecorative3, with: nil)
            Color.compound.override(\.textDecorative4, with: nil)
            Color.compound.override(\.textDecorative5, with: nil)
            Color.compound.override(\.textDecorative6, with: nil)
        }
        
        let decorative = Color.compound.decorativeColor(for: "@alice:branga.ru")
        #expect(decorative.background == .red)
        #expect(decorative.text == .blue)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/khamit/element_x_ios_fork && xcodegen
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/DecorativeColorOverrideTests 2>&1 | tail -20
```

Expected: **TEST FAILED** — `decorative.background` is still the stock Compound color, because the array was captured in `init`.

- [ ] **Step 3: Make `decorativeColors` computed**

In `compound-ios/Sources/Compound/Colors/CompoundColors.swift`, replace the `init` and the `decorativeColors` declaration (currently lines 49–67):

```swift
    init() {
        tokens = CompoundColorTokens()
    }
    
    // MARK: - Decorative Colors
    
    // Used to determine the background and text colors of avatars, usernames etc.
    
    // TG-SKIN: computed (upstream: `let` captured in init) so runtime token
    // overrides reach avatars/sender names. See docs/fork-slimming.md.
    // Explicit subscript form: SwiftFormat would strip a bare `self.` and the
    // dynamic-member lookup with it.
    var decorativeColors: [DecorativeColor] {
        [.init(background: self[dynamicMember: \.bgDecorative1], text: self[dynamicMember: \.textDecorative1]),
         .init(background: self[dynamicMember: \.bgDecorative2], text: self[dynamicMember: \.textDecorative2]),
         .init(background: self[dynamicMember: \.bgDecorative3], text: self[dynamicMember: \.textDecorative3]),
         .init(background: self[dynamicMember: \.bgDecorative4], text: self[dynamicMember: \.textDecorative4]),
         .init(background: self[dynamicMember: \.bgDecorative5], text: self[dynamicMember: \.textDecorative5]),
         .init(background: self[dynamicMember: \.bgDecorative6], text: self[dynamicMember: \.textDecorative6])]
    }
```

Keep everything else in the file untouched (including `decorativeColor(for:)` and the underscore tokens below).

- [ ] **Step 4: Run test to verify it passes**

Same command as Step 2. Expected: **TEST SUCCEEDED**.

- [ ] **Step 5: Lint and commit**

```bash
cd /Users/khamit/element_x_ios_fork && swiftformat --lint . && swiftlint lint --quiet
git add compound-ios/Sources/Compound/Colors/CompoundColors.swift UnitTests/Sources/DecorativeColorOverrideTests.swift
git commit -m "Make Compound decorative colors reflect runtime overrides

decorativeColors was a stored array captured in init, so the token
override mechanism never reached avatar and sender-name colors. Computed
property reads through the override-aware subscript instead. TG-SKIN
marked; behavioural change only, values are identical when no overrides
are set.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: TelegramThemeHook — the mapping + registration

**Files:**
- Create: `ElementX/Sources/AppHooks/Hooks/TelegramThemeHook.swift`
- Modify: `ElementX/Sources/AppHooks/AppHooks+Fork.swift` (add one registration line)
- Test: `UnitTests/Sources/TelegramThemeHookTests.swift`

**Interfaces:**
- Consumes: `TelegramPalette.dynamic(day:night:)` etc. (Task 1); override-aware `decorativeColor(for:)` (Task 2); upstream `CompoundHookProtocol` (`@MainActor func override(colors: CompoundColors, uiColors: CompoundUIColors)`) and `AppHooks.registerCompoundHook(_:)`.
- Produces: `struct TelegramThemeHook: CompoundHookProtocol` with `func override(colors:uiColors:)` and `func removeOverrides(colors:uiColors:)` (tests use the latter to restore process-global state). Registered in `AppHooks+Fork.setUp()`; `AppCoordinator` applies it automatically at startup.

**Module note:** the mapping table names `CompoundColorTokens`/`CompoundUIColorTokens`, which live in the transitive SPM module `CompoundDesignTokens`. `import CompoundDesignTokens` compiles in Xcode for transitive package deps. If it ever fails to resolve: add `CompoundDesignTokens: { url: https://github.com/element-hq/compound-design-tokens, exactVersion: 10.2.3 }` under `packages:` in `project.yml` and `- package: CompoundDesignTokens` to `ElementX/SupportingFiles/target.yml` deps, both with `# TG-SKIN` comments.

- [ ] **Step 1: Write the failing test**

Create `UnitTests/Sources/TelegramThemeHookTests.swift`:

```swift
//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX

import Compound
import SwiftUI
import Testing
import UIKit

@Suite
struct TelegramThemeHookTests {
    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)
    
    @Test
    func appliesTelegramDayAndNightPalette() {
        let hook = TelegramThemeHook()
        hook.override(colors: Color.compound, uiColors: UIColor.compound)
        defer { hook.removeOverrides(colors: Color.compound, uiColors: UIColor.compound) }
        
        // UIKit path, day + night.
        #expect(UIColor.compound.bgCanvasDefault.resolvedColor(with: light).hexString == "#FFFFFF")
        #expect(UIColor.compound.bgCanvasDefault.resolvedColor(with: dark).hexString == "#000000")
        #expect(UIColor.compound.textActionAccent.resolvedColor(with: light).hexString == "#0088FF")
        #expect(UIColor.compound.textActionAccent.resolvedColor(with: dark).hexString == "#3E88F7")
        #expect(UIColor.compound.textCriticalPrimary.resolvedColor(with: light).hexString == "#FF3B30")
        #expect(UIColor.compound.textCriticalPrimary.resolvedColor(with: dark).hexString == "#EB5545")
        #expect(UIColor.compound.separatorPrimary.resolvedColor(with: light).hexString == "#C8C7CC")
        
        // SwiftUI path resolves through the same dynamic provider.
        #expect(UIColor(Color.compound.textPrimary).resolvedColor(with: light).hexString == "#000000")
        #expect(UIColor(Color.compound.textPrimary).resolvedColor(with: dark).hexString == "#FFFFFF")
    }
    
    @Test
    func removingOverridesRestoresCompoundDefaults() {
        let hook = TelegramThemeHook()
        let stock = UIColor.compound.bgCanvasDefault.resolvedColor(with: light).hexString
        hook.override(colors: Color.compound, uiColors: UIColor.compound)
        hook.removeOverrides(colors: Color.compound, uiColors: UIColor.compound)
        #expect(UIColor.compound.bgCanvasDefault.resolvedColor(with: light).hexString == stock)
    }
    
    @Test
    func sendersGetTelegramPeerNameColors() {
        let hook = TelegramThemeHook()
        hook.override(colors: Color.compound, uiColors: UIColor.compound)
        defer { hook.removeOverrides(colors: Color.compound, uiColors: UIColor.compound) }
        
        // The six overridden textDecorative slots are Telegram peer-name colors
        // (displayOrder minus pink); any contentID must land on one of them.
        let telegramPeerHexes: Set<String> = ["#368AD1", "#40A920", "#D67722", "#CC5049", "#955CDB", "#309EBA"]
        let senderColor = UIColor(Color.compound.decorativeColor(for: "@alice:branga.ru").text)
        #expect(telegramPeerHexes.contains(senderColor.resolvedColor(with: light).hexString))
    }
    
    @Test
    func forkRegistersThemeHook() {
        let hooks = AppHooks()
        hooks.setUp()
        #expect(hooks.compoundHook is TelegramThemeHook)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/khamit/element_x_ios_fork && xcodegen
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/TelegramThemeHookTests 2>&1 | tail -20
```

Expected: **BUILD FAILED** — `cannot find 'TelegramThemeHook' in scope`.

- [ ] **Step 3: Write the hook**

Create `ElementX/Sources/AppHooks/Hooks/TelegramThemeHook.swift`:

```swift
//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import CompoundDesignTokens
import SwiftUI

/// Fork customisation: re-skins the app to Telegram's Day/Night palette by
/// overriding Compound's semantic colour tokens at startup (AppCoordinator applies
/// the registered compound hook before building any UI). Raw values and their
/// Telegram source keys: TelegramPalette + the palette reference doc. Entries
/// marked `derived:` have no Telegram equivalent and are fair game for tuning.
/// See docs/fork-slimming.md (TG-SKIN).
struct TelegramThemeHook: CompoundHookProtocol {
    func override(colors: CompoundColors, uiColors: CompoundUIColors) {
        for mapping in Self.mappings {
            colors.override(mapping.color, with: Color(mapping.value))
            uiColors.override(mapping.uiColor, with: mapping.value)
        }
    }
    
    /// Restores Compound defaults. Test-only; production never unsets the theme.
    func removeOverrides(colors: CompoundColors, uiColors: CompoundUIColors) {
        for mapping in Self.mappings {
            colors.override(mapping.color, with: nil)
            uiColors.override(mapping.uiColor, with: nil)
        }
    }
    
    private typealias P = TelegramPalette
    
    // swiftlint:disable:next large_tuple
    private static let mappings: [(color: KeyPath<CompoundColorTokens, Color>, uiColor: KeyPath<CompoundUIColorTokens, UIColor>, value: UIColor)] = [
        // MARK: Text
        (\.textPrimary, \.textPrimary, P.dynamic(day: 0x000000, night: 0xFFFFFF)), // list.itemPrimaryTextColor
        (\.textSecondary, \.textSecondary, P.dynamic(day: 0x8E8E93, night: 0x98989E)), // list.itemSecondaryTextColor
        (\.textDisabled, \.textDisabled, P.dynamic(day: 0x8E8E93, night: 0x8F8F8F)), // list.itemDisabledTextColor
        (\.textActionAccent, \.textActionAccent, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // defaultDayAccentColor / dark accent
        (\.textActionPrimary, \.textActionPrimary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // rootController.navigationBar.buttonColor
        (\.textActionSuccess, \.textActionSuccess, P.dynamic(day: 0x26972C, night: 0x30CF30)), // list.freeTextSuccessColor
        (\.textOnSolidPrimary, \.textOnSolidPrimary, P.dynamic(day: 0xFFFFFF, night: 0xFFFFFF)), // inputPanel.actionControlForegroundColor
        (\.textLinkExternal, \.textLinkExternal, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // list.itemAccentColor
        (\.textCriticalPrimary, \.textCriticalPrimary, P.dynamic(day: 0xFF3B30, night: 0xEB5545)), // list.itemDestructiveColor
        (\.textSuccessPrimary, \.textSuccessPrimary, P.dynamic(day: 0x26972C, night: 0x30CF30)), // list.freeTextSuccessColor
        (\.textInfoPrimary, \.textInfoPrimary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // derived: accent
        (\.textBadgeAccent, \.textBadgeAccent, P.dynamic(day: 0xFFFFFF, night: 0xFFFFFF)), // chatList.unreadBadgeActiveTextColor
        (\.textBadgeInfo, \.textBadgeInfo, P.dynamic(day: 0xFFFFFF, night: 0xFFFFFF)), // navigationBar.badgeTextColor
        // MARK: Text decorative (sender names) — Telegram peer-name colors, displayOrder minus pink
        (\.textDecorative1, \.textDecorative1, P.dynamic(day: 0x368AD1, night: 0x368AD1)), // PeerNameColors key 5 blue
        (\.textDecorative2, \.textDecorative2, P.dynamic(day: 0x40A920, night: 0x40A920)), // key 3 green
        (\.textDecorative3, \.textDecorative3, P.dynamic(day: 0xD67722, night: 0xD67722)), // key 1 orange
        (\.textDecorative4, \.textDecorative4, P.dynamic(day: 0xCC5049, night: 0xCC5049)), // key 0 red
        (\.textDecorative5, \.textDecorative5, P.dynamic(day: 0x955CDB, night: 0x955CDB)), // key 2 violet
        (\.textDecorative6, \.textDecorative6, P.dynamic(day: 0x309EBA, night: 0x309EBA)), // key 4 cyan
        // MARK: Canvas / subtle backgrounds
        (\.bgCanvasDefault, \.bgCanvasDefault, P.dynamic(day: 0xFFFFFF, night: 0x000000)), // chatList.backgroundColor
        (\.bgCanvasDefaultLevel1, \.bgCanvasDefaultLevel1, P.dynamic(day: 0xFFFFFF, night: 0x1C1C1D)), // list.itemBlocksBackgroundColor
        (\.bgCanvasDisabled, \.bgCanvasDisabled, P.dynamic(day: 0xEFEFF4, night: 0x1C1C1D)), // derived: blocksBackground
        (\.bgSubtlePrimary, \.bgSubtlePrimary, P.dynamic(day: 0xE5E5EA, night: 0x2C2C2E)), // list.itemHighlightedBackgroundColor / itemModalBlocksBackgroundColor
        (\.bgSubtleSecondary, \.bgSubtleSecondary, P.dynamic(day: 0xEFEFF4, night: 0x1C1C1D)), // list.blocksBackgroundColor / itemBlocksBackgroundColor
        (\.bgSubtleSecondaryLevel0, \.bgSubtleSecondaryLevel0, P.dynamic(day: 0xEFEFF4, night: 0x000000)), // list.blocksBackgroundColor
        (\.bgSubtleTertiary, \.bgSubtleTertiary, P.dynamic(day: 0xF7F7F7, night: 0x1C1C1D)), // chatList.pinnedItemBackgroundColor
        // MARK: Action backgrounds
        (\.bgActionPrimaryRest, \.bgActionPrimaryRest, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // accent (filled buttons)
        (\.bgActionPrimaryHovered, \.bgActionPrimaryHovered, P.dynamic(day: 0x0080F0, night: 0x3679DE)), // derived: accent darkened
        (\.bgActionPrimaryPressed, \.bgActionPrimaryPressed, P.dynamic(day: 0x0077D9, night: 0x2F6BC5)), // derived: accent darkened
        (\.bgActionPrimaryDisabled, \.bgActionPrimaryDisabled, P.dynamic(day: 0xD0D0D0, night: 0x525252)), // navigationBar.disabledButtonColor
        (\.bgActionSecondaryRest, \.bgActionSecondaryRest, P.dynamic(day: 0xFFFFFF, night: 0x1C1C1D)), // list.itemBlocksBackgroundColor
        (\.bgActionSecondaryHovered, \.bgActionSecondaryHovered, P.dynamic(day: 0xE5E5EA, night: 0x2C2C2E)), // derived
        (\.bgActionSecondaryPressed, \.bgActionSecondaryPressed, P.dynamic(day: 0xDADADE, night: 0x313135)), // derived: messageDay highlightedFill / itemHighlightedBackground
        // MARK: Accent backgrounds
        (\.bgAccentRest, \.bgAccentRest, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // accent
        (\.bgAccentHovered, \.bgAccentHovered, P.dynamic(day: 0x0080F0, night: 0x3679DE)), // derived
        (\.bgAccentPressed, \.bgAccentPressed, P.dynamic(day: 0x0077D9, night: 0x2F6BC5)), // derived
        (\.bgAccentSelected, \.bgAccentSelected, P.dynamic(day: 0xE9F0FA, night: 0x191919)), // chatList.itemSelectedBackgroundColor
        (\.bgAccentSubtle, \.bgAccentSubtle, P.dynamic(day: 0xD9EBFF, night: 0x1C2E4A)), // derived: pale accent
        // MARK: Critical / success / info backgrounds
        (\.bgCriticalPrimary, \.bgCriticalPrimary, P.dynamic(day: 0xFF3B30, night: 0xEB5545)), // destructive
        (\.bgCriticalHovered, \.bgCriticalHovered, P.dynamic(day: 0xE5352B, night: 0xD54C3E)), // derived
        (\.bgCriticalSubtle, \.bgCriticalSubtle, P.dynamic(day: 0xFFEBEA, night: 0x2D1210)), // derived: pale destructive
        (\.bgCriticalSubtleHovered, \.bgCriticalSubtleHovered, P.dynamic(day: 0xFFD6D4, night: 0x3E1B18)), // derived
        (\.bgSuccessRest, \.bgSuccessRest, P.dynamic(day: 0x35C759, night: 0x67CE67)), // list.itemSwitchColors.contentColor
        (\.bgSuccessHovered, \.bgSuccessHovered, P.dynamic(day: 0x2FB350, night: 0x5CBF5C)), // derived
        (\.bgSuccessPressed, \.bgSuccessPressed, P.dynamic(day: 0x28A046, night: 0x52B052)), // derived
        (\.bgSuccessSubtle, \.bgSuccessSubtle, P.dynamic(day: 0xE3F7E9, night: 0x122B12)), // derived: pale success
        (\.bgInfoSubtle, \.bgInfoSubtle, P.dynamic(day: 0xE5F2FF, night: 0x14233B)), // derived: pale accent
        // MARK: Badges
        (\.bgBadgeAccent, \.bgBadgeAccent, P.dynamic(day: 0xD9EBFF, night: 0x1C2E4A)), // derived: pale accent
        (\.bgBadgeCritical, \.bgBadgeCritical, P.dynamic(day: 0xFF3B30, night: 0xEB5545)), // navigationBar.badgeBackgroundColor
        (\.bgBadgeDefault, \.bgBadgeDefault, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // chatList.unreadBadgeActiveBackgroundColor
        (\.bgBadgePrimary, \.bgBadgePrimary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // chatList.unreadBadgeActiveBackgroundColor
        (\.bgBadgeSecondary, \.bgBadgeSecondary, P.dynamic(day: 0xB6B6BB, night: 0x666666)), // chatList.unreadBadgeInactiveBackgroundColor
        (\.bgBadgeInfo, \.bgBadgeInfo, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // derived: accent badge
        // MARK: Decorative backgrounds (avatars) — derived pastels of the peer-name colors
        (\.bgDecorative1, \.bgDecorative1, P.dynamic(day: 0xE1EEF8, night: 0x14293D)), // derived: pale blue
        (\.bgDecorative2, \.bgDecorative2, P.dynamic(day: 0xE3F2DE, night: 0x14300B)), // derived: pale green
        (\.bgDecorative3, \.bgDecorative3, P.dynamic(day: 0xF9EBDE, night: 0x3D2410)), // derived: pale orange
        (\.bgDecorative4, \.bgDecorative4, P.dynamic(day: 0xF7E5E4, night: 0x3A1917)), // derived: pale red
        (\.bgDecorative5, \.bgDecorative5, P.dynamic(day: 0xEFE7FA, night: 0x2B1C40)), // derived: pale violet
        (\.bgDecorative6, \.bgDecorative6, P.dynamic(day: 0xE0F0F5, night: 0x0F2D36)), // derived: pale cyan
        // MARK: Icons
        (\.iconPrimary, \.iconPrimary, P.dynamic(day: 0x000000, night: 0xFFFFFF)), // list.itemPrimaryTextColor
        (\.iconPrimaryAlpha, \.iconPrimaryAlpha, P.dynamic(day: 0x000000, night: 0xFFFFFF)), // list.itemPrimaryTextColor
        (\.iconSecondary, \.iconSecondary, P.dynamic(day: 0x8E8E93, night: 0x98989E)), // list.itemSecondaryTextColor
        (\.iconSecondaryAlpha, \.iconSecondaryAlpha, P.dynamic(day: 0x8E8E93, night: 0x98989E)), // list.itemSecondaryTextColor
        (\.iconTertiary, \.iconTertiary, P.dynamic(day: 0xA7A7AD, night: 0x8D8E93)), // chatList.muteIconColor
        (\.iconTertiaryAlpha, \.iconTertiaryAlpha, P.dynamic(day: 0xA7A7AD, night: 0x8D8E93)), // chatList.muteIconColor
        (\.iconQuaternary, \.iconQuaternary, P.dynamic(day: 0xBAB9BE, night: 0xFFFFFF, nightAlpha: 0.28)), // list.disclosureArrowColor
        (\.iconQuaternaryAlpha, \.iconQuaternaryAlpha, P.dynamic(day: 0xBAB9BE, night: 0xFFFFFF, nightAlpha: 0.28)), // list.disclosureArrowColor
        (\.iconDisabled, \.iconDisabled, P.dynamic(day: 0xC8C8CE, night: 0x4D4D4D)), // list.itemPlaceholderTextColor
        (\.iconAccentPrimary, \.iconAccentPrimary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // accent
        (\.iconAccentTertiary, \.iconAccentTertiary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // accent
        (\.iconCriticalPrimary, \.iconCriticalPrimary, P.dynamic(day: 0xFF3B30, night: 0xEB5545)), // destructive
        (\.iconSuccessPrimary, \.iconSuccessPrimary, P.dynamic(day: 0x26972C, night: 0x30CF30)), // list.freeTextSuccessColor
        (\.iconInfoPrimary, \.iconInfoPrimary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // derived: accent
        (\.iconOnSolidPrimary, \.iconOnSolidPrimary, P.dynamic(day: 0xFFFFFF, night: 0xFFFFFF)), // inputPanel.actionControlForegroundColor
        // MARK: Separators & borders
        (\.separatorPrimary, \.separatorPrimary, P.dynamic(day: 0xC8C7CC, night: 0x545458, nightAlpha: 0.55)), // list.itemBlocksSeparatorColor
        (\.separatorSecondary, \.separatorSecondary, P.dynamic(day: 0xE5E5EA, night: 0x2C2C2E)), // derived: lighter separator
        (\.borderDisabled, \.borderDisabled, P.dynamic(day: 0xC8C7CC, night: 0x545458, nightAlpha: 0.55)), // list.itemBlocksSeparatorColor
        (\.borderFocused, \.borderFocused, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // accent
        (\.borderInteractivePrimary, \.borderInteractivePrimary, P.dynamic(day: 0xC7C7CC, night: 0xFFFFFF, nightAlpha: 0.3)), // list.itemCheckColors.strokeColor
        (\.borderInteractiveSecondary, \.borderInteractiveSecondary, P.dynamic(day: 0xD6D6DC, night: 0x39393D)), // navigationBar.segmentedDividerColor / itemSwitchColors.frameColor
        (\.borderInteractiveHovered, \.borderInteractiveHovered, P.dynamic(day: 0xB6B6BB, night: 0x767677)), // derived
        (\.borderAccentPrimary, \.borderAccentPrimary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // accent
        (\.borderAccentSubtle, \.borderAccentSubtle, P.dynamic(day: 0xB8DCFF, night: 0x28457A)), // derived: pale accent
        (\.borderCriticalPrimary, \.borderCriticalPrimary, P.dynamic(day: 0xFF3B30, night: 0xEB5545)), // destructive
        (\.borderCriticalHovered, \.borderCriticalHovered, P.dynamic(day: 0xE5352B, night: 0xD54C3E)), // derived
        (\.borderCriticalSubtle, \.borderCriticalSubtle, P.dynamic(day: 0xFFC7C4, night: 0x54221E)), // derived: pale destructive
        (\.borderSuccessPrimary, \.borderSuccessPrimary, P.dynamic(day: 0x26972C, night: 0x30CF30)), // list.freeTextSuccessColor
        (\.borderSuccessSubtle, \.borderSuccessSubtle, P.dynamic(day: 0xBFEBCC, night: 0x1E4A1E)), // derived: pale success
        (\.borderInfoSubtle, \.borderInfoSubtle, P.dynamic(day: 0xBFDFFF, night: 0x1F3A66)) // derived: pale accent
    ]
}
```

Deliberately NOT overridden (Compound defaults kept): the 14 `gradient*` tokens, `bgActionTertiary*` (3), `textWarningPrimary`, `iconWarningPrimary` — no Telegram equivalent and near-invisible surfaces. The underscore "awaiting" tokens (`_bgBubbleIncoming` etc.) are stored `let`s the mechanism cannot reach; bubbles are Phase 4's job.

- [ ] **Step 4: Register the hook**

In `ElementX/Sources/AppHooks/AppHooks+Fork.swift`, change `setUp()`:

```swift
    func setUp() {
        registerAppSettingsHook(ForkAppSettingsHook())
        registerCompoundHook(TelegramThemeHook())
    }
```

- [ ] **Step 5: Run test to verify it passes**

Same command as Step 2. Expected: **TEST SUCCEEDED**, 4 tests pass.
If `import CompoundDesignTokens` fails to resolve, apply the fallback from the Module note above, run `xcodegen`, retry.

- [ ] **Step 6: Run all three new suites together**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ElementX.xcodeproj -scheme UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UnitTests/TelegramPaletteTests \
  -only-testing:UnitTests/DecorativeColorOverrideTests \
  -only-testing:UnitTests/TelegramThemeHookTests 2>&1 | tail -20
```

Expected: **TEST SUCCEEDED**, 9 tests pass.

- [ ] **Step 7: Lint and commit**

```bash
cd /Users/khamit/element_x_ios_fork && swiftformat --lint . && swiftlint lint --quiet
git add ElementX/Sources/AppHooks/Hooks/TelegramThemeHook.swift ElementX/Sources/AppHooks/AppHooks+Fork.swift UnitTests/Sources/TelegramThemeHookTests.swift
git commit -m "Apply Telegram Day/Night palette via a compound hook

TelegramThemeHook overrides ~90 Compound semantic colour tokens with
Telegram's Day (light) and Night (dark) values at startup, registered
through the existing CompoundHookProtocol extension point so no
upstream call sites change. Derived values (no Telegram equivalent)
are marked in the mapping for future tuning.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Merge-survival docs

**Files:**
- Modify: `docs/fork-slimming.md` (append section)

**Interfaces:**
- Consumes: nothing new. Produces: the TG-SKIN section future merges rely on.

- [ ] **Step 1: Append the section**

Append to `docs/fork-slimming.md` (adapt heading level to the file's existing structure):

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add docs/fork-slimming.md
git commit -m "Document the Telegram skin in the fork-slimming playbook

TG-SKIN marker inventory and post-merge re-skin checklist, mirroring
the existing re-slim checklist.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Verify on simulator + device, open PR

**Files:** none (verification + PR).

**Interfaces:** consumes everything above.

- [ ] **Step 1: Build and screenshot on simulator (light + dark)**

```bash
cd /Users/khamit/element_x_ios_fork
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing \
  -project ElementX.xcodeproj -scheme ElementX \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/neutrino-tg-theme 2>&1 | tail -3
xcrun simctl boot "iPhone 17" 2>/dev/null; sleep 5
xcrun simctl install booted /tmp/neutrino-tg-theme/Build/Products/Debug-iphonesimulator/ElementX.app
xcrun simctl launch booted com.khamitovdr.elementx; sleep 5
xcrun simctl io booted screenshot /tmp/neutrino-tg-theme/light.png
xcrun simctl ui booted appearance dark; sleep 2
xcrun simctl io booted screenshot /tmp/neutrino-tg-theme/dark.png
```

Expected: the login/onboarding screen shows Telegram colors — blue `0x0088FF` primary button on white in light; `0x3E88F7` on black in dark. Read both PNGs to confirm before proceeding (this is the visual gate; if buttons are still Element green, the hook isn't registered — stop and debug).

- [ ] **Step 2: Install on the user's iPhone**

Ask the user to unlock their iPhone, then:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project ElementX.xcodeproj -scheme ElementX -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/neutrino-tg-theme-device \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration 2>&1 | tail -3
xcrun devicectl list devices
xcrun devicectl device install app --device <udid-from-list-output> \
  /tmp/neutrino-tg-theme-device/Build/Products/Debug-iphoneos/ElementX.app
```

Do NOT pass `--terminate-existing`. Ask the user to open Neutrino and compare chat list + settings side-by-side with Telegram (logged-in surfaces only exist on their phone).

- [ ] **Step 3: Push branch and open PR**

```bash
git push -u origin feature/telegram-skin
gh pr create --repo khamitovdr/element-x-ios --base develop \
  --title "Add Telegram Day/Night theme layer" \
  --label pr-feature \
  --body "$(cat <<'EOF'
Phase 0+1 of the Telegram skin (spec + plan in docs/superpowers/): raw palette transcribed from the vendored Telegram-iOS sources, applied app-wide at startup via the upstream CompoundHookProtocol extension point. One TG-SKIN-marked edit in compound-ios makes avatar/sender decorative colors override-aware; everything else is fork-owned files.

Additions exceed the 500 guideline because the docs (spec, plan, palette reference) and the transcribed palette data dominate the diff; executable logic is ~150 lines.

No snapshot re-record needed: previews never run the hook, so PreviewTests are untouched by design.

| Light | Dark |
|---|---|
| (attach light.png) | (attach dark.png) |

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Attach the two simulator screenshots to the PR description (drag into GitHub or `gh pr edit` with uploaded links). Expected: PR opens against `khamitovdr/element-x-ios` `develop` with the `pr-feature` label.

- [ ] **Step 4: Watch CI**

```bash
gh pr checks --repo khamitovdr/element-x-ios --watch
```

Expected: unit tests pass on CI (the ~26 known local environmental failures pass there; our three new suites must pass). If "Element CI" pushes commits or workflow runs need approval, approve via `gh api -X POST repos/khamitovdr/element-x-ios/actions/runs/<id>/approve`.
