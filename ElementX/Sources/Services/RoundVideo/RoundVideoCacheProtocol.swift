//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

nonisolated protocol RoundVideoCacheProtocol: Sendable {
    /// A fresh URL to record into, named with the round video marker and current date.
    func urlForNewRecording() -> URL
    /// Removes all cached round video files.
    func clearCache()
}

// sourcery: AutoMockable
extension RoundVideoCacheProtocol { }
