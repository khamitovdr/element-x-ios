//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

/// Which format the composer's record button captures. Toggled by tapping the button.
enum MediaRecordingMode: String, Codable {
    case voice
    case roundVideo
}
