//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

extension View {
    /// - Parameters:
    ///   - isOutgoing: rounds the corners according to the side it shows on, defaults to true
    ///   - insets: defaults to what we use for file timeline items, text uses custom values
    ///   - color: self explanatory, defaults to subtle secondary
    ///   - usesDefaultBubbleColor: TG-SKIN — true when `color` is the plain default bubble token
    ///     rather than `nil` or an item-specific override (e.g. the critical scanning-failure
    ///     colour); default outgoing bubbles then get the screen-anchored gradient instead of a
    ///     flat fill. Defaults to false so unrelated callers (previews, swipe/long-press feedback)
    ///     keep their flat fill.
    ///   - borderColor: an optional colour for a border around the bubble
    func bubbleBackground(isOutgoing: Bool = true,
                          insets: EdgeInsets = .init(top: 8, leading: 12, bottom: 8, trailing: 12),
                          color: @autoclosure @MainActor () -> Color? = .compound.bgSubtleSecondary,
                          usesDefaultBubbleColor: Bool = false,
                          borderColor: @autoclosure @MainActor () -> Color? = nil) -> some View {
        modifier(TimelineItemBubbleBackgroundModifier(isOutgoing: isOutgoing,
                                                      insets: insets,
                                                      color: color(),
                                                      usesDefaultBubbleColor: usesDefaultBubbleColor,
                                                      borderColor: borderColor()))
    }
}

private struct TimelineItemBubbleBackgroundModifier: ViewModifier {
    @Environment(\.timelineGroupStyle) private var timelineGroupStyle
    
    let isOutgoing: Bool
    let insets: EdgeInsets
    var color: Color?
    var usesDefaultBubbleColor: Bool
    var borderColor: Color?
    
    // TG-SKIN: Telegram's merged-corner bubble shape (with tail) replaces Element's fixed 12pt
    // corner radius. The tail draws outside the content bounds by design; backgrounds don't clip.
    // Default outgoing bubbles get the screen-anchored gradient; everything else (incoming,
    // overrides, no background at all) keeps a flat fill.
    func body(content: Content) -> some View {
        let shape = TelegramBubbleShape(groupStyle: timelineGroupStyle, isOutgoing: isOutgoing)
        content
            .padding(insets)
            .background {
                if isOutgoing, usesDefaultBubbleColor {
                    shape.fill(.clear).background(TelegramBubbleGradient().clipShape(shape))
                } else {
                    shape.fill(color ?? .clear)
                }
            }
            .overlay {
                if let borderColor {
                    shape.stroke(borderColor)
                }
            }
    }
}
