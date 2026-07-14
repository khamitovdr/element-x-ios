//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementX
import Foundation
import Testing

struct RoundVideoRecorderStateTests {
    @Test
    func stateFollowsRecorderActions() async throws {
        let actionsSubject = PassthroughSubject<RoundVideoRecorderAction, Never>()
        let recorder = RoundVideoRecorderMock()
        recorder.actions = actionsSubject.eraseToAnyPublisher()
        recorder.isRecording = false
        recorder.currentTime = 0
        recorder.cameraPosition = .front
        
        let state = RoundVideoRecorderState()
        state.attachRecorder(recorder)
        #expect(state.recordingState == .stopped)
        
        let deferredRecording = deferFulfillment(state.$recordingState) { $0 == .recording }
        actionsSubject.send(.didStartRecording)
        try await deferredRecording.fulfill()
        
        let deferredStopped = deferFulfillment(state.$recordingState) { $0 == .stopped }
        actionsSubject.send(.didStopRecording(url: URL(filePath: "/tmp/round-video-test.mp4"), duration: 3))
        try await deferredStopped.fulfill()
    }
    
    @Test
    func attachingRunningRecorderStartsInRecordingState() {
        let recorder = RoundVideoRecorderMock()
        recorder.actions = PassthroughSubject<RoundVideoRecorderAction, Never>().eraseToAnyPublisher()
        recorder.isRecording = true
        recorder.currentTime = 5
        recorder.cameraPosition = .front
        
        let state = RoundVideoRecorderState()
        state.attachRecorder(recorder)
        #expect(state.recordingState == .recording)
    }
}
