//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Combine
import Foundation

nonisolated enum RoundVideoRecorderError: Error, Equatable {
    case cameraPermissionNotGranted
    case microphonePermissionNotGranted
    case configurationFailure
    case writerFailure
    case interrupted
    case missingRecordingFile
    case failedSendingRoundVideo
}

nonisolated enum RoundVideoRecorderAction {
    case didStartRecording
    case didStopRecording(url: URL, duration: TimeInterval)
    case didFailWithError(error: RoundVideoRecorderError)
}

nonisolated enum RoundVideoCameraPosition {
    case front
    case back
    
    var avPosition: AVCaptureDevice.Position {
        switch self {
        case .front: .front
        case .back: .back
        }
    }
    
    var flipped: RoundVideoCameraPosition {
        switch self {
        case .front: .back
        case .back: .front
        }
    }
}

nonisolated protocol RoundVideoRecorderProtocol: AnyObject, Sendable {
    var actions: AnyPublisher<RoundVideoRecorderAction, Never> { get }
    var isRecording: Bool { get }
    /// Elapsed recording time, for driving the live UI.
    var currentTime: TimeInterval { get }
    var recordingURL: URL? { get }
    /// Duration of the finished recording (valid after `didStopRecording`).
    var recordingDuration: TimeInterval { get }
    var cameraPosition: RoundVideoCameraPosition { get }
    /// The live capture session, exposed so the recording overlay can show a camera preview.
    var captureSession: AVCaptureSession? { get }
    
    func startRecording() async
    func stopRecording() async
    func cancelRecording() async
    func deleteRecording() async
    func flipCamera() async
    
    func sendRoundVideo(timelineController: TimelineControllerProtocol) async -> Result<Void, RoundVideoRecorderError>
}

// sourcery: AutoMockable
extension RoundVideoRecorderProtocol { }
