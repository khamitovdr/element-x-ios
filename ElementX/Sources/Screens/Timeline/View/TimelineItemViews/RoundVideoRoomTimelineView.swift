//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Compound
import SwiftUI

/// A Telegram-style round video message: a circular bubble that downloads the video on
/// tap and plays it inline with sound, with a progress ring around the rim.
struct RoundVideoRoomTimelineView: View {
    @Environment(\.timelineContext) private var context
    let timelineItem: VideoRoomTimelineItem
    
    private static let diameter: CGFloat = 240
    
    @State private var player: AVPlayer?
    @State private var fileHandle: MediaFileHandleProxy?
    @State private var isLoading = false
    @State private var isPlaying = false
    @State private var didFail = false
    @State private var progress: Double = 0
    
    // Stored so @State ticks don't rebuild the publisher on every body evaluation.
    private let progressTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        TimelineStyler(timelineItem: timelineItem) {
            content
                .frame(width: Self.diameter, height: Self.diameter)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(UntranslatedL10n.commonVideoMessageIos)
        }
        .onDisappear {
            if isPlaying {
                context?.send(viewAction: .roundVideoPlaybackStopped(itemID: timelineItem.id))
            }
            player?.pause()
            player = nil
            fileHandle = nil
            isPlaying = false
            progress = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { notification in
            guard let item = notification.object as? AVPlayerItem, item === player?.currentItem else { return }
            finishPlayback()
        }
        .onReceive(progressTimer) { _ in
            guard isPlaying, let player else { return }
            
            // The environment context isn't observed, so enforce the one-at-a-time rule
            // here: pause when another round video (or a voice message) took over.
            if context?.viewState.currentlyPlayingRoundVideoItemID != timelineItem.id {
                player.pause()
                isPlaying = false
                return
            }
            
            guard let duration = player.currentItem?.duration.seconds, duration > 0 else { return }
            progress = player.currentTime().seconds / duration
        }
    }
    
    private var content: some View {
        ZStack {
            thumbnail
            
            if let player {
                RoundVideoPlayerView(player: player)
                    .opacity(isPlaying || progress > 0 ? 1 : 0)
            }
            
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if didFail {
                CompoundIcon(\.error, size: .medium, relativeTo: .compound.headingLG)
                    .foregroundStyle(.compound.iconCriticalPrimary)
            } else if !isPlaying {
                CompoundIcon(\.playSolid, size: .medium, relativeTo: .compound.headingLG)
                    .foregroundStyle(.white)
                    .padding(13)
                    .background(.black.opacity(0.4), in: .circle)
            }
        }
        .clipShape(Circle())
        .overlay {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.compound.iconAccentTertiary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(1.5)
        }
        .overlay(alignment: .bottom) {
            durationBadge
        }
        .contentShape(Circle())
        .onTapGesture {
            handleTap()
        }
    }
    
    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailSource = timelineItem.content.thumbnailInfo?.source {
            LoadableImage(mediaSource: thumbnailSource,
                          mediaType: .timelineItem(uniqueID: timelineItem.id.uniqueID),
                          blurhash: timelineItem.content.blurhash,
                          size: timelineItem.content.thumbnailInfo?.size,
                          mediaProvider: context?.mediaProvider) { imageView in
                imageView
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                placeholder
            }
        } else {
            placeholder
        }
    }
    
    private var placeholder: some View {
        Rectangle()
            .foregroundStyle(timelineItem.isOutgoing ? .compound._bgBubbleOutgoing : .compound._bgBubbleIncoming)
    }
    
    private var durationBadge: some View {
        Text(DateFormatter.roundVideoElapsedFormatter.string(from: Date(timeIntervalSinceReferenceDate: timelineItem.content.videoInfo.duration)))
            .font(.compound.bodyXSSemibold)
            .foregroundStyle(.white)
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.black.opacity(0.5), in: .capsule)
            .padding(.bottom, 8)
            .opacity(isPlaying ? 0 : 1)
    }
    
    // MARK: - Playback
    
    private func handleTap() {
        didFail = false
        if isPlaying {
            player?.pause()
            isPlaying = false
            context?.send(viewAction: .roundVideoPlaybackStopped(itemID: timelineItem.id))
        } else if let player {
            play(player)
        } else {
            Task { await loadAndPlay() }
        }
    }
    
    private func loadAndPlay() async {
        guard !isLoading, let mediaProvider = context?.mediaProvider else { return }
        let source = timelineItem.content.videoInfo.source
        
        isLoading = true
        defer { isLoading = false }
        
        switch await mediaProvider.loadFileFromSource(source, filename: timelineItem.content.filename) {
        case .success(let handle):
            guard let url = handle.url else {
                didFail = true
                return
            }
            // Keep the handle alive for as long as we hold the player, it owns the file.
            fileHandle = handle
            let player = AVPlayer(url: url)
            self.player = player
            play(player)
        case .failure(let error):
            MXLog.error("Failed loading round video: \(error)")
            didFail = true
        }
    }
    
    private func play(_ player: AVPlayer) {
        context?.send(viewAction: .roundVideoPlaybackStarted(itemID: timelineItem.id))
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        if progress >= 0.999 {
            player.seek(to: .zero)
            progress = 0
        }
        player.play()
        isPlaying = true
    }
    
    private func finishPlayback() {
        isPlaying = false
        progress = 0
        player?.seek(to: .zero)
        context?.send(viewAction: .roundVideoPlaybackStopped(itemID: timelineItem.id))
    }
}

struct RoundVideoRoomTimelineView_Previews: PreviewProvider, TestablePreview {
    static let viewModel = TimelineViewModel.mock
    
    static var previews: some View {
        VStack(spacing: 20.0) {
            RoundVideoRoomTimelineView(timelineItem: makeTimelineItem(isOutgoing: false))
            RoundVideoRoomTimelineView(timelineItem: makeTimelineItem(isOutgoing: true))
        }
        .environmentObject(viewModel.context)
        .environment(\.timelineContext, viewModel.context)
        .previewLayout(.sizeThatFits)
        .padding(.vertical, 20)
    }
    
    private static func makeTimelineItem(isOutgoing: Bool) -> VideoRoomTimelineItem {
        VideoRoomTimelineItem(id: .randomEvent,
                              timestamp: .mock,
                              isOutgoing: isOutgoing,
                              isEditable: false,
                              canBeRepliedTo: true,
                              sender: .init(id: "Bob"),
                              content: .init(filename: "round-video-20260713-101500.mp4",
                                             videoInfo: .mockVideo,
                                             thumbnailInfo: .mockVideoThumbnail,
                                             blurhash: "L%KUc%kqS$RP?Ks,WEf8OlrqaekW",
                                             isRoundVideo: true))
    }
}
