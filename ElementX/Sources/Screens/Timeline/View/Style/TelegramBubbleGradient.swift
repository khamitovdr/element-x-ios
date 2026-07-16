//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

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
