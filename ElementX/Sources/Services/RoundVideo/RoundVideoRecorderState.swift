//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Combine
import Foundation
import UIKit

enum RoundVideoRecorderRecordingState {
    case recording
    case stopped
    case error
}

class RoundVideoRecorderState: ObservableObject, Identifiable {
    let id = UUID()
    
    @Published private(set) var recordingState: RoundVideoRecorderRecordingState = .stopped
    @Published private(set) var duration = 0.0
    @Published private(set) var cameraPosition: RoundVideoCameraPosition = .front
    
    /// The capture session backing the live circular preview, if any.
    var captureSession: AVCaptureSession? {
        recorder?.captureSession
    }
    
    private weak var recorder: RoundVideoRecorderProtocol?
    private var cancellables: Set<AnyCancellable> = []
    private var displayLink: CADisplayLink?
    
    func attachRecorder(_ recorder: RoundVideoRecorderProtocol) {
        recordingState = .stopped
        self.recorder = recorder
        subscribeToRecorder(recorder)
        if recorder.isRecording {
            recordingState = .recording
            startPublishUpdates()
        }
    }
    
    func detachRecorder() async {
        if let recorder, recorder.isRecording {
            await recorder.stopRecording()
        }
        stopPublishUpdates()
        cancellables = []
        recorder = nil
        recordingState = .stopped
    }
    
    func reportError() {
        recordingState = .error
    }
    
    // MARK: - Private
    
    private func subscribeToRecorder(_ recorder: RoundVideoRecorderProtocol) {
        recorder.actions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in
                self?.handleRecorderAction(action)
            }
            .store(in: &cancellables)
    }
    
    private func handleRecorderAction(_ action: RoundVideoRecorderAction) {
        switch action {
        case .didStartRecording:
            startPublishUpdates()
            recordingState = .recording
        case .didStopRecording:
            stopPublishUpdates()
            recordingState = .stopped
        case .didFailWithError:
            stopPublishUpdates()
            recordingState = .stopped
        }
    }
    
    private func startPublishUpdates() {
        if displayLink != nil {
            stopPublishUpdates()
        }
        displayLink = CADisplayLink(target: self, selector: #selector(publishUpdate))
        displayLink?.preferredFrameRateRange = .init(minimum: 10, maximum: 30)
        displayLink?.add(to: .current, forMode: .common)
    }
    
    // periphery:ignore:parameters displayLink - required for objc selector
    @objc private func publishUpdate(displayLink: CADisplayLink) {
        if let currentTime = recorder?.currentTime {
            duration = currentTime
        }
        if let position = recorder?.cameraPosition {
            cameraPosition = position
        }
    }
    
    private func stopPublishUpdates() {
        displayLink?.invalidate()
        displayLink = nil
    }
}

extension RoundVideoRecorderState: Equatable {
    nonisolated static func == (lhs: RoundVideoRecorderState, rhs: RoundVideoRecorderState) -> Bool {
        lhs.id == rhs.id
    }
}
