//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

final nonisolated class RoundVideoCache: RoundVideoCacheProtocol {
    private var temporaryFilesFolderURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("media/round-video")
    }
    
    func urlForNewRecording() -> URL {
        setupTemporaryFilesFolder()
        return temporaryFilesFolderURL.appendingPathComponent(RoundVideoMessage.filename(for: Date()))
    }
    
    func clearCache() {
        if FileManager.default.fileExists(atPath: temporaryFilesFolderURL.path) {
            do {
                try FileManager.default.removeItem(at: temporaryFilesFolderURL)
            } catch {
                MXLog.error("Failed clearing cached round video files. \(error)")
            }
        }
    }
    
    private func setupTemporaryFilesFolder() {
        do {
            try FileManager.default.createDirectoryIfNeeded(at: temporaryFilesFolderURL, withIntermediateDirectories: true)
        } catch {
            MXLog.error("Failed to setup round video cache folder.")
        }
    }
}
