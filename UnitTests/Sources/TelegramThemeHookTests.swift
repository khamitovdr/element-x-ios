//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
@testable import ElementX
import SwiftUI
import Testing
import UIKit

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
        let telegramPeerHexes: Set = ["#368AD1", "#40A920", "#D67722", "#CC5049", "#955CDB", "#309EBA"]
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
