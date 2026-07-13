//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// Constants and wire-format conventions for Telegram-style round video messages.
///
/// A round video is sent as a standard `m.video` event whose filename carries the
/// `round-video-` marker, so every other Matrix client renders an ordinary video.
nonisolated enum RoundVideoMessage {
    /// The output is a square of this many pixels (matches Telegram's video notes).
    static let dimension = 400
    /// Recordings stop automatically when reaching this duration.
    static let maxDuration: TimeInterval = 60
    /// Target H.264 bitrate, keeps a full-length message under ~6 MB.
    static let videoBitrate = 700_000
    static let audioBitrate = 64000
    
    static let filenamePrefix = "round-video-"
    static let mimeType = "video/mp4"
    
    /// Heuristic bounds: bridged Telegram video notes are 400×400 and ≤ 60 s.
    private static let heuristicMaxDimension: UInt64 = 480
    private static let heuristicMaxDuration: TimeInterval = 62
    
    static func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "\(filenamePrefix)\(formatter.string(from: date)).mp4"
    }
    
    /// Whether an `m.video` event should render as a round video message.
    ///
    /// Either it carries our filename marker (square as a sanity check), or it matches
    /// the square/small/short heuristic that catches Telegram video notes arriving
    /// through a mautrix-telegram bridge.
    static func isRoundVideo(filename: String?, width: UInt64?, height: UInt64?, duration: TimeInterval?) -> Bool {
        guard let width, let height, width == height, width > 0 else {
            return false
        }
        
        if filename?.hasPrefix(filenamePrefix) == true {
            return true
        }
        
        guard let duration, duration > 0, duration <= heuristicMaxDuration else {
            return false
        }
        
        return width <= heuristicMaxDimension
    }
}
