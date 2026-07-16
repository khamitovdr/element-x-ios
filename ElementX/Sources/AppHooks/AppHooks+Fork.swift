//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation

#if IS_MAIN_APP
extension AppHooks {
    /// Fork extension point: upstream ships only the no-op protocol default,
    /// so this concrete method wins and registers the fork's hooks.
    func setUp() {
        registerAppSettingsHook(ForkAppSettingsHook())
        registerCompoundHook(TelegramThemeHook())
    }
}
#endif
