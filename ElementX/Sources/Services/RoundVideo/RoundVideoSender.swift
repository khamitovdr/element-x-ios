//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// Builds the `VideoInfo` for a finished round video recording and sends it through the
/// regular video pipeline, which handles encryption, upload and retries.
enum RoundVideoSender {
    static func send(url: URL,
                     duration: TimeInterval,
                     timelineController: TimelineControllerProtocol) async -> Result<Void, RoundVideoRecorderError> {
        let thumbnail: RoundVideoThumbnailer.Thumbnail
        do {
            thumbnail = try await RoundVideoThumbnailer.generateThumbnail(for: url)
        } catch {
            MXLog.error("Failed generating round video thumbnail. \(error)")
            return .failure(.failedSendingRoundVideo)
        }
        
        let size: UInt64
        let thumbnailSize: UInt64
        do {
            size = try UInt64(FileManager.default.sizeForItem(at: url))
            thumbnailSize = try UInt64(FileManager.default.sizeForItem(at: thumbnail.url))
        } catch {
            MXLog.error("Failed to get round video file sizes. \(error)")
            return .failure(.failedSendingRoundVideo)
        }
        
        let videoInfo = VideoInfo(duration: duration,
                                  height: UInt64(RoundVideoMessage.dimension),
                                  width: UInt64(RoundVideoMessage.dimension),
                                  mimetype: RoundVideoMessage.mimeType,
                                  size: size,
                                  thumbnailInfo: ThumbnailInfo(height: UInt64(thumbnail.height),
                                                               width: UInt64(thumbnail.width),
                                                               mimetype: "image/jpeg",
                                                               size: thumbnailSize),
                                  thumbnailSource: nil,
                                  blurhash: thumbnail.blurhash)
        
        let result = await timelineController.sendVideo(url: url,
                                                        thumbnailURL: thumbnail.url,
                                                        videoInfo: videoInfo,
                                                        caption: nil) { _ in }
        
        if case .failure(let error) = result {
            MXLog.error("Failed to send round video. \(error)")
            return .failure(.failedSendingRoundVideo)
        }
        
        return .success(())
    }
}
