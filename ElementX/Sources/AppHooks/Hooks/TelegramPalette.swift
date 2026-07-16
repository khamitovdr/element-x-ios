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
