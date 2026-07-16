//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// Telegram's outgoing-bubble gradient, applied bubble-locally: a plain top → bottom
/// `LinearGradient` over the bubble's own bounds. Telegram itself anchors this gradient to
/// the SCREEN, not the bubble, so each bubble shows the slice at its on-screen position,
/// shifting as you scroll (`WallpaperBackgroundNode.contentsRect` behaviour — see the bubble
/// reference doc). Reproducing that needs a live scroll-position feed a per-cell
/// `UIHostingConfiguration` can't supply — `.global` geometry resolves cell-locally and never
/// updates during UIKit scrolling — so screen-anchored authenticity is ledgered as follow-up
/// polish, not implemented here. TG-SKIN (fork-owned).
enum TelegramBubbleGradient {
    static func gradient(for colorScheme: ColorScheme) -> LinearGradient {
        let colors = colorScheme == .dark
            ? TelegramPalette.Chat.outgoingBubbleGradientNight
            : TelegramPalette.Chat.outgoingBubbleGradientDay
        return LinearGradient(colors: colors.map { Color(TelegramPalette.rgb($0)) },
                              startPoint: .top,
                              endPoint: .bottom)
    }
}
