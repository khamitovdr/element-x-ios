//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
@testable import ElementX
import SwiftUI
import Testing
import UIKit

struct TelegramBubbleShapeTests {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 60)
    
    @Test
    func tailOnlyOnLastAndSingle() {
        #expect(TelegramBubbleShape(groupStyle: .single, isOutgoing: true).hasTail)
        #expect(TelegramBubbleShape(groupStyle: .last, isOutgoing: true).hasTail)
        #expect(!TelegramBubbleShape(groupStyle: .first, isOutgoing: true).hasTail)
        #expect(!TelegramBubbleShape(groupStyle: .middle, isOutgoing: true).hasTail)
    }
    
    @Test
    func tailExtendsBeyondBodyOnTheCorrectSide() {
        let outgoing = TelegramBubbleShape(groupStyle: .last, isOutgoing: true).path(in: rect)
        #expect(outgoing.boundingRect.maxX > rect.maxX)
        #expect(outgoing.boundingRect.minX == rect.minX)
        
        let incoming = TelegramBubbleShape(groupStyle: .last, isOutgoing: false).path(in: rect)
        #expect(incoming.boundingRect.minX < rect.minX)
        #expect(incoming.boundingRect.maxX == rect.maxX)
        
        let middle = TelegramBubbleShape(groupStyle: .middle, isOutgoing: true).path(in: rect)
        #expect(middle.boundingRect == rect)
    }
    
    @Test
    func mergedCornersAreTighter() {
        // A point 3pt inside the top-trailing corner: outside a 16pt arc, inside an 8pt arc.
        let probe = CGPoint(x: rect.maxX - 3, y: rect.minY + 3)
        #expect(!TelegramBubbleShape(groupStyle: .single, isOutgoing: true).path(in: rect).contains(probe))
        #expect(TelegramBubbleShape(groupStyle: .middle, isOutgoing: true).path(in: rect).contains(probe))
        // Leading corners never merge: mirrored probe stays outside for both.
        let leadingProbe = CGPoint(x: rect.minX + 3, y: rect.minY + 3)
        #expect(!TelegramBubbleShape(groupStyle: .middle, isOutgoing: true).path(in: rect).contains(leadingProbe))
    }
    
    @Test
    func tailSeamIsFilled() {
        // Winding-cancellation regression: these probes sit inside the body's rounded
        // bottom-tail-side corner AND inside the tail's rectangular flange - exactly the
        // overlap where opposite subpath winding directions cancel under the default
        // nonzero fill rule. (Probes right at the body edge, e.g. maxX-2/minX+2, don't
        // discriminate: CoreGraphics rasterizes the coincident-edge case as filled either
        // way, so the regression only shows up further into the overlap, hence -10/-15.)
        let outgoing = TelegramBubbleShape(groupStyle: .last, isOutgoing: true).path(in: rect)
        #expect(outgoing.contains(CGPoint(x: rect.maxX - 10, y: rect.maxY - 10)))
        #expect(outgoing.contains(CGPoint(x: rect.maxX - 15, y: rect.maxY - 5)))
        let incoming = TelegramBubbleShape(groupStyle: .single, isOutgoing: false).path(in: rect)
        #expect(incoming.contains(CGPoint(x: rect.minX + 10, y: rect.maxY - 10)))
        #expect(incoming.contains(CGPoint(x: rect.minX + 15, y: rect.maxY - 5)))
    }
}

struct TelegramBubbleColorTests {
    @Test
    func bubbleTokensCarryTelegramValues() {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let incoming = UIColor(Color.compound._bgBubbleIncoming)
        #expect(incoming.resolvedColor(with: light).hexString == "#F1F1F4")
        #expect(incoming.resolvedColor(with: dark).hexString == "#1D1D1D")
        let outgoing = UIColor(Color.compound._bgBubbleOutgoing)
        #expect(outgoing.resolvedColor(with: light).hexString == "#2B9DEF") // gradient midpoint, derived
        #expect(outgoing.resolvedColor(with: dark).hexString == "#30A2FC") // gradient midpoint, derived
    }
}
