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
import WysiwygComposer

struct RoundVideoComposerToolbarTests {
    @Test
    func toggleRecordingModeFlipsAndPersists() {
        let appSettings = AppSettings.volatile()
        let viewModel = makeViewModel(appSettings: appSettings)
        
        #expect(viewModel.context.viewState.mediaRecordingMode == .voice)
        
        viewModel.context.send(viewAction: .toggleRecordingMode)
        #expect(viewModel.context.viewState.mediaRecordingMode == .roundVideo)
        #expect(appSettings.preferredMediaRecordingMode == .roundVideo)
        
        viewModel.context.send(viewAction: .toggleRecordingMode)
        #expect(viewModel.context.viewState.mediaRecordingMode == .voice)
        #expect(appSettings.preferredMediaRecordingMode == .voice)
    }
    
    @Test
    func initialModeComesFromSettings() {
        let appSettings = AppSettings.volatile()
        appSettings.preferredMediaRecordingMode = .roundVideo
        let viewModel = makeViewModel(appSettings: appSettings)
        #expect(viewModel.context.viewState.mediaRecordingMode == .roundVideo)
    }
    
    @Test
    func sendInRoundVideoPreviewEmitsRoundVideoSend() async throws {
        let viewModel = makeViewModel(appSettings: .volatile())
        viewModel.process(timelineAction: .setMode(mode: .previewRoundVideo(url: URL(filePath: "/tmp/round-video-test.mp4"),
                                                                            duration: 3,
                                                                            isUploading: false)))
        
        let deferred = deferFulfillment(viewModel.actions) { action in
            if case .roundVideo(.send) = action {
                return true
            }
            return false
        }
        viewModel.context.send(viewAction: .sendMessage)
        try await deferred.fulfill()
    }
    
    @Test
    func roundVideoActionsAreForwarded() async throws {
        let viewModel = makeViewModel(appSettings: .volatile())
        let deferred = deferFulfillment(viewModel.actions) { action in
            if case .roundVideo(.startRecording) = action {
                return true
            }
            return false
        }
        viewModel.context.send(viewAction: .roundVideo(.startRecording))
        try await deferred.fulfill()
    }
    
    // MARK: - Helpers
    
    private func makeViewModel(appSettings: AppSettings) -> ComposerToolbarViewModel {
        ComposerToolbarViewModel(roomProxy: JoinedRoomProxyMock(.init()),
                                 wysiwygViewModel: WysiwygComposerViewModel(),
                                 completionSuggestionService: CompletionSuggestionServiceMock(configuration: .init()),
                                 mediaProvider: MediaProviderMock(.init()),
                                 mentionDisplayHelper: ComposerMentionDisplayHelper.mock,
                                 appSettings: appSettings,
                                 analyticsService: AnalyticsServiceMock(.init()),
                                 composerDraftService: ComposerDraftServiceMock(.init()))
    }
}
