//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

struct RoundVideoThumbnailerTests {
    @Test
    func generatesSquareJPEGThumbnailWithBlurhash() async throws {
        let videoURL = try await RoundVideoTestFixtures.makeTestVideo(filename: "round-video-thumbnail-test.mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }
        
        let thumbnail = try await RoundVideoThumbnailer.generateThumbnail(for: videoURL)
        defer { try? FileManager.default.removeItem(at: thumbnail.url) }
        
        #expect(FileManager.default.fileExists(atPath: thumbnail.url.path))
        #expect(thumbnail.url.pathExtension == "jpeg")
        #expect(thumbnail.width == 400)
        #expect(thumbnail.height == 400)
        #expect(thumbnail.blurhash != nil)
    }
}
