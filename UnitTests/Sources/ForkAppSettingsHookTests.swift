//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Testing

struct ForkAppSettingsHookTests {
    @Test
    func configurePinsServerAndDisablesUnusedFeatures() {
        let appSettings = AppSettings.volatile()
        // Simulate stale persisted toggles from before the fork slimming.
        appSettings.threadsEnabled = true
        appSettings.roomThreadListEnabled = true
        appSettings.knockingEnabled = true
        appSettings.linkNewDeviceEnabled = true
        
        let configured = ForkAppSettingsHook().configure(appSettings)
        
        #expect(configured.accountProviders == ["branga.ru"])
        #expect(configured.allowOtherAccountProviders == false)
        #expect(configured.threadsEnabled == false)
        #expect(configured.roomThreadListEnabled == false)
        #expect(configured.knockingEnabled == false)
        #expect(configured.linkNewDeviceEnabled == false)
    }
}
