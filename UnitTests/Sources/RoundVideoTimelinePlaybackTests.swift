//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

/// Pins the pure state transitions of `TimelineViewModel`'s round-video playback tracking:
/// `state.currentlyPlayingRoundVideoItemID` governs which inline cell (if any) is allowed to
/// play, and must be cleared whenever something else is about to make sound.
@MainActor
struct RoundVideoTimelinePlaybackTests {
    @Test
    func playbackStartedSetsPlayingItemID() {
        let viewModel = makeViewModel()
        let itemID = TimelineItemIdentifier.randomEvent
        
        viewModel.process(viewAction: .roundVideoPlaybackStarted(itemID: itemID))
        
        #expect(viewModel.state.currentlyPlayingRoundVideoItemID == itemID)
    }
    
    @Test
    func playbackStoppedOnlyClearsMatchingItemID() {
        let viewModel = makeViewModel()
        let playingItemID = TimelineItemIdentifier.randomEvent
        let otherItemID = TimelineItemIdentifier.randomEvent
        
        viewModel.process(viewAction: .roundVideoPlaybackStarted(itemID: playingItemID))
        #expect(viewModel.state.currentlyPlayingRoundVideoItemID == playingItemID)
        
        // Stopping a different item shouldn't touch the currently playing one.
        viewModel.process(viewAction: .roundVideoPlaybackStopped(itemID: otherItemID))
        #expect(viewModel.state.currentlyPlayingRoundVideoItemID == playingItemID)
        
        viewModel.process(viewAction: .roundVideoPlaybackStopped(itemID: playingItemID))
        #expect(viewModel.state.currentlyPlayingRoundVideoItemID == nil)
    }
    
    @Test
    func previewPlaybackStartedStopsInlinePlayback() {
        let viewModel = makeViewModel()
        let itemID = TimelineItemIdentifier.randomEvent
        
        viewModel.process(viewAction: .roundVideoPlaybackStarted(itemID: itemID))
        #expect(viewModel.state.currentlyPlayingRoundVideoItemID == itemID)
        
        viewModel.process(composerAction: .roundVideo(.previewPlaybackStarted))
        
        #expect(viewModel.state.currentlyPlayingRoundVideoItemID == nil)
    }
    
    // The `.startRecording` paths kick off a real recorder `Task` that goes on to request
    // camera/microphone permission and fail harmlessly in the test environment, but the
    // synchronous clear below happens before that `Task` is even created, so it's safe to
    // assert on immediately.
    
    @Test
    func startingRoundVideoRecordingStopsInlinePlayback() {
        let viewModel = makeViewModel()
        let itemID = TimelineItemIdentifier.randomEvent
        
        viewModel.process(viewAction: .roundVideoPlaybackStarted(itemID: itemID))
        #expect(viewModel.state.currentlyPlayingRoundVideoItemID == itemID)
        
        viewModel.process(composerAction: .roundVideo(.startRecording))
        
        #expect(viewModel.state.currentlyPlayingRoundVideoItemID == nil)
    }
    
    @Test
    func startingVoiceMessageRecordingStopsInlinePlayback() {
        let viewModel = makeViewModel()
        let itemID = TimelineItemIdentifier.randomEvent
        
        viewModel.process(viewAction: .roundVideoPlaybackStarted(itemID: itemID))
        #expect(viewModel.state.currentlyPlayingRoundVideoItemID == itemID)
        
        viewModel.process(composerAction: .voiceMessage(.startRecording))
        
        #expect(viewModel.state.currentlyPlayingRoundVideoItemID == nil)
    }
    
    // MARK: - Helpers
    
    private func makeViewModel() -> TimelineViewModel {
        let appSettings = AppSettings.volatile()
        
        return TimelineViewModel(roomProxy: JoinedRoomProxyMock(.init(name: "")),
                                 timelineController: TimelineControllerMock(.init(timelineItems: [])),
                                 userSession: UserSessionMock(.init()),
                                 mediaPlayerProvider: MediaPlayerProviderMock(),
                                 userIndicatorController: UserIndicatorControllerMock(),
                                 appMediator: AppMediatorMock(.init()),
                                 appSettings: appSettings,
                                 analyticsService: AnalyticsServiceMock(.init()),
                                 emojiProvider: EmojiProvider(appSettings: appSettings),
                                 linkMetadataProvider: LinkMetadataProvider(),
                                 timelineControllerFactory: TimelineControllerFactoryMock(.init()))
    }
}
