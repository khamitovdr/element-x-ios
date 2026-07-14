//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Foundation
import UIKit

enum RoundVideoThumbnailerError: Error {
    case failedGeneratingThumbnail
}

nonisolated enum RoundVideoThumbnailer {
    struct Thumbnail {
        let url: URL
        let width: Double
        let height: Double
        let blurhash: String?
    }
    
    /// Generates a first-frame JPEG thumbnail (plus blurhash) next to the given video file.
    static func generateThumbnail(for videoURL: URL) async throws -> Thumbnail {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
        generator.appliesPreferredTrackTransform = true
        
        let cgImage = try await generator.image(at: .zero).image
        let image = UIImage(cgImage: cgImage)
        
        guard let data = image.jpegData(compressionQuality: 0.78) else {
            throw RoundVideoThumbnailerError.failedGeneratingThumbnail
        }
        
        let blurhash = await image.blurHash(numberOfComponents: (3, 3))
        
        let url = videoURL.deletingPathExtension().appendingPathExtension("jpeg")
        try data.write(to: url)
        
        return Thumbnail(url: url, width: image.size.width, height: image.size.height, blurhash: blurhash)
    }
}
