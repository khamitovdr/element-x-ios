//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

struct RoundVideoMessageTests {
    @Test
    func markerFilenameSquareIsRound() {
        #expect(RoundVideoMessage.isRoundVideo(filename: "round-video-20260713-101500.mp4", width: 400, height: 400, duration: 12))
    }
    
    @Test
    func markerFilenameNonSquareIsNotRound() {
        #expect(!RoundVideoMessage.isRoundVideo(filename: "round-video-20260713-101500.mp4", width: 1920, height: 1080, duration: 12))
    }
    
    @Test
    func bridgedTelegramVideoNoteIsRound() {
        // mautrix-telegram bridges Telegram video notes as 400×400 with an arbitrary filename.
        #expect(RoundVideoMessage.isRoundVideo(filename: "video_note.mp4", width: 400, height: 400, duration: 59))
    }
    
    @Test
    func largeSquareVideoIsNotRound() {
        #expect(!RoundVideoMessage.isRoundVideo(filename: "square.mp4", width: 720, height: 720, duration: 30))
    }
    
    @Test
    func longSmallSquareVideoIsNotRound() {
        #expect(!RoundVideoMessage.isRoundVideo(filename: "square.mp4", width: 400, height: 400, duration: 300))
    }
    
    @Test
    func missingInfoIsNotRound() {
        #expect(!RoundVideoMessage.isRoundVideo(filename: "round-video-x.mp4", width: nil, height: nil, duration: nil))
        #expect(!RoundVideoMessage.isRoundVideo(filename: nil, width: 400, height: 400, duration: nil))
        #expect(!RoundVideoMessage.isRoundVideo(filename: nil, width: 0, height: 0, duration: 10))
    }
    
    @Test
    func generatedFilenameCarriesMarkerAndRoundTrips() {
        let filename = RoundVideoMessage.filename(for: Date(timeIntervalSince1970: 0))
        #expect(filename.hasPrefix("round-video-"))
        #expect(filename.hasSuffix(".mp4"))
        #expect(RoundVideoMessage.isRoundVideo(filename: filename, width: 400, height: 400, duration: nil))
    }
}
