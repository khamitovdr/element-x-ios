//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// Telegram's message bubble: 16pt corners, 8pt on the tail-side corners that touch a
/// grouped neighbour, and a ~6×17pt tail on the last message of a group. Geometry
/// transcribed from ChatMessageBubbleImages.swift — see
/// docs/superpowers/specs/2026-07-16-telegram-bubble-reference.md. TG-SKIN (fork-owned).
struct TelegramBubbleShape: Shape {
    let groupStyle: TimelineGroupStyle
    let isOutgoing: Bool
    
    private static let maxRadius: CGFloat = 16
    private static let minRadius: CGFloat = 8
    private static let tailWidth: CGFloat = 6
    private static let tailHeight: CGFloat = 17
    
    // `Shape.path(in:)` is a nonisolated protocol requirement, so this type is inferred nonisolated too.
    // Pattern-matching (rather than `==`) avoids `TimelineGroupStyle`'s main-actor-isolated `Equatable`
    // witness, which can't be called from a nonisolated context.
    var hasTail: Bool {
        switch groupStyle {
        case .single, .last: true
        case .first, .middle: false
        }
    }
    
    func path(in rect: CGRect) -> Path {
        // Radii in tail-side terms, then mapped to left/right. Tail side never reduces
        // its bottom corner when the tail is present.
        let (tailTop, tailBottom): (CGFloat, CGFloat) = switch groupStyle {
        case .single: (Self.maxRadius, Self.maxRadius)
        case .first: (Self.maxRadius, Self.minRadius)
        case .middle: (Self.minRadius, Self.minRadius)
        case .last: (Self.minRadius, Self.maxRadius)
        }
        
        let (topLeft, topRight, bottomLeft, bottomRight) = isOutgoing
            ? (Self.maxRadius, tailTop, Self.maxRadius, tailBottom)
            : (tailTop, Self.maxRadius, tailBottom, Self.maxRadius)
        
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight), radius: topRight,
                    startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight), radius: bottomRight,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft), radius: bottomLeft,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft), radius: topLeft,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        
        if hasTail {
            path.addPath(tailPath(in: rect))
        }
        return path
    }
    
    /// The lens-shaped tail hugging the bottom tail-side corner: sweeps along the bottom
    /// edge past the body, returns up the side with a concave curve (the reference's
    /// carved-ellipse notch, approximated with a quad curve).
    private func tailPath(in rect: CGRect) -> Path {
        var path = Path()
        if isOutgoing {
            // Traversal order reversed relative to the `else` branch (not a plain mirror of it):
            // mirroring the body's corners across x flips the rotational sense a same-shaped
            // subpath would need to match it, so matching the body's winding on both sides
            // requires the two branches to trace their (mirrored) geometry in opposite orders.
            // Verified by rendering: see TelegramBubbleShapeTests.tailSeamIsFilled.
            path.move(to: CGPoint(x: rect.maxX - Self.maxRadius, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - Self.maxRadius, y: rect.maxY - Self.tailHeight))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - Self.tailHeight))
            path.addQuadCurve(to: CGPoint(x: rect.maxX + Self.tailWidth, y: rect.maxY),
                              control: CGPoint(x: rect.maxX + 1, y: rect.maxY - 6))
        } else {
            path.move(to: CGPoint(x: rect.minX + Self.maxRadius, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX - Self.tailWidth, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - Self.tailHeight),
                              control: CGPoint(x: rect.minX - 1, y: rect.maxY - 6))
            path.addLine(to: CGPoint(x: rect.minX + Self.maxRadius, y: rect.maxY - Self.tailHeight))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

struct TelegramBubbleShape_Previews: PreviewProvider, TestablePreview {
    static let groupStyles: [TimelineGroupStyle] = [.single, .first, .middle, .last]
    
    static var previews: some View {
        HStack(alignment: .top, spacing: 24) {
            column(isOutgoing: false)
            column(isOutgoing: true)
        }
        .padding(24)
        .previewLayout(.sizeThatFits)
    }
    
    static func column(isOutgoing: Bool) -> some View {
        VStack(spacing: 12) {
            ForEach(groupStyles, id: \.self) { groupStyle in
                TelegramBubbleShape(groupStyle: groupStyle, isOutgoing: isOutgoing)
                    .fill(isOutgoing ? Color.compound._bgBubbleOutgoing : Color.compound._bgBubbleIncoming)
                    .frame(width: 140, height: 44)
            }
        }
    }
}
