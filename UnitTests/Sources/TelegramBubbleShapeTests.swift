//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import SwiftUI
import Testing

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
}
