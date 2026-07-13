//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import MatrixRustSDK
import Testing

@MainActor
struct RoundVideoSenderTests {
    @Test
    func sendUsesMarkerFilenameAndSquareVideoInfo() async throws {
        let videoURL = try await RoundVideoTestFixtures.makeTestVideo(filename: RoundVideoMessage.filename(for: Date()))
        defer { try? FileManager.default.removeItem(at: videoURL) }
        
        let timelineController = TimelineControllerMock()
        var sentURL: URL?
        var sentVideoInfo: VideoInfo?
        var sentCaption: String?
        timelineController.sendVideoUrlThumbnailURLVideoInfoCaptionRequestHandleClosure = { url, _, videoInfo, caption, _ in
            sentURL = url
            sentVideoInfo = videoInfo
            sentCaption = caption
            return .success(())
        }
        
        let result = await RoundVideoSender.send(url: videoURL, duration: 0.5, timelineController: timelineController)
        
        guard case .success = result else {
            Issue.record("Sending should succeed")
            return
        }
        
        let url = try #require(sentURL)
        let videoInfo = try #require(sentVideoInfo)
        #expect(url.lastPathComponent.hasPrefix(RoundVideoMessage.filenamePrefix))
        #expect(videoInfo.width == UInt64(RoundVideoMessage.dimension))
        #expect(videoInfo.height == UInt64(RoundVideoMessage.dimension))
        #expect(videoInfo.mimetype == "video/mp4")
        #expect(videoInfo.thumbnailInfo != nil)
        #expect(sentCaption == nil)
    }
    
    @Test
    func sendFailsWhenControllerFails() async throws {
        let videoURL = try await RoundVideoTestFixtures.makeTestVideo(filename: RoundVideoMessage.filename(for: Date()))
        defer { try? FileManager.default.removeItem(at: videoURL) }
        
        let timelineController = TimelineControllerMock()
        timelineController.sendVideoUrlThumbnailURLVideoInfoCaptionRequestHandleReturnValue = .failure(.generic)
        
        let result = await RoundVideoSender.send(url: videoURL, duration: 0.5, timelineController: timelineController)
        
        guard case .failure(.failedSendingRoundVideo) = result else {
            Issue.record("Sending should fail with failedSendingRoundVideo")
            return
        }
    }
}
