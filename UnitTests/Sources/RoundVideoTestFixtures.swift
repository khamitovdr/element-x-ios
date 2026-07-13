//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import CoreVideo
import Foundation

enum RoundVideoTestFixturesError: Error {
    case pixelBufferCreationFailed
    case writerFailed
}

enum RoundVideoTestFixtures {
    /// Writes a short 400×400 H.264 mp4 (solid grey frames, no audio) into the temp
    /// directory and returns its URL.
    static func makeTestVideo(filename: String) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                       AVVideoWidthKey: 400,
                                       AVVideoHeightKey: 400]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let attributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                         kCVPixelBufferWidthKey as String: 400,
                                         kCVPixelBufferHeightKey as String: 400]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        for frame in 0..<15 {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(10))
            }
            guard let pool = adaptor.pixelBufferPool else { throw RoundVideoTestFixturesError.pixelBufferCreationFailed }
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            guard let pixelBuffer else { throw RoundVideoTestFixturesError.pixelBufferCreationFailed }
            
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
                memset(base, 128, CVPixelBufferGetDataSize(pixelBuffer))
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            
            adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw RoundVideoTestFixturesError.writerFailed }
        return url
    }
}
