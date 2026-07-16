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
