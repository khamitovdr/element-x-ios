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
    ///     colour); default outgoing bubbles then get the gradient fill instead of a flat one.
    ///     Defaults to false so unrelated callers (previews, swipe/long-press feedback) keep
    ///     their flat fill.
    ///   - borderColor: an optional colour for a border around the bubble
    ///   - showsTail: TG-SKIN — false suppresses the tail regardless of group style, keeping
    ///     16pt corners all round. Used by non-chat bubble presentations (e.g. the media
    ///     browser) that don't want the timeline's grouped-tail affordance. Defaults to true.
    func bubbleBackground(isOutgoing: Bool = true,
                          insets: EdgeInsets = .init(top: 8, leading: 12, bottom: 8, trailing: 12),
                          color: @autoclosure @MainActor () -> Color? = .compound.bgSubtleSecondary,
                          usesDefaultBubbleColor: Bool = false,
                          borderColor: @autoclosure @MainActor () -> Color? = nil,
                          showsTail: Bool = true) -> some View {
        modifier(TimelineItemBubbleBackgroundModifier(isOutgoing: isOutgoing,
                                                      insets: insets,
                                                      color: color(),
                                                      usesDefaultBubbleColor: usesDefaultBubbleColor,
                                                      borderColor: borderColor(),
                                                      showsTail: showsTail))
    }
}

private struct TimelineItemBubbleBackgroundModifier: ViewModifier {
    @Environment(\.timelineGroupStyle) private var timelineGroupStyle
    @Environment(\.colorScheme) private var colorScheme
    
    let isOutgoing: Bool
    let insets: EdgeInsets
    var color: Color?
    var usesDefaultBubbleColor: Bool
    var borderColor: Color?
    var showsTail: Bool
    
    // TG-SKIN: Telegram's merged-corner bubble shape (with tail) replaces Element's fixed 12pt
    // corner radius. The tail draws outside the content bounds by design; backgrounds don't clip.
    // Filling the shape directly (rather than filling a separate background view and clipping
    // it to the shape) is what paints the tail — a plain View only paints its own bounds even
    // once clipped, so `.fill(.clear).background(gradientView.clipShape(shape))` never covered
    // the tail. Default outgoing bubbles get a bubble-local gradient fill; everything else
    // (incoming, overrides, no background at all) keeps a flat fill.
    func body(content: Content) -> some View {
        let shape = TelegramBubbleShape(groupStyle: timelineGroupStyle, isOutgoing: isOutgoing, showsTail: showsTail)
        content
            .padding(insets)
            .background {
                if isOutgoing, usesDefaultBubbleColor {
                    shape.fill(TelegramBubbleGradient.gradient(for: colorScheme))
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
