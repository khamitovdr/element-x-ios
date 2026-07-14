//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Compound
import SwiftUI

/// A large circular overlay shown over the timeline while recording or previewing a
/// round video message, Telegram-style.
struct RoundVideoComposerOverlay: View {
    @ObservedObject var context: ComposerToolbarViewModel.Context
    
    var body: some View {
        switch context.viewState.composerMode {
        case .recordRoundVideo:
            RoundVideoRecordingCircle(recorderState: context.viewState.roundVideoRecorderState) {
                context.send(viewAction: .roundVideo(.flipCamera))
            }
        case .previewRoundVideo(let url, let duration, let isUploading):
            RoundVideoPreviewCircle(url: url, duration: duration, isUploading: isUploading) {
                context.send(viewAction: .roundVideo(.previewPlaybackStarted))
            }
        default:
            EmptyView()
        }
    }
}

private struct RoundVideoRecordingCircle: View {
    @ObservedObject var recorderState: RoundVideoRecorderState
    let onFlipCamera: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                circle
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(.compound.iconCriticalPrimary)
                        .frame(width: 8, height: 8)
                    Text(DateFormatter.roundVideoElapsedFormatter.string(from: Date(timeIntervalSinceReferenceDate: recorderState.duration)))
                        .font(.compound.bodyMDSemibold)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                
                Button(action: onFlipCamera) {
                    // Compound has no camera-flip icon, hence the SF Symbol.
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.camera")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.white.opacity(0.2), in: .circle)
                }
                .accessibilityLabel(UntranslatedL10n.a11yVideoMessageFlipCameraIos)
            }
        }
    }
    
    private var circle: some View {
        ZStack {
            if let session = recorderState.captureSession {
                RoundVideoCameraPreviewView(session: session)
            } else {
                Circle()
                    .fill(.compound.bgSubtleSecondary)
                    .overlay {
                        CompoundIcon(\.videoCallSolid, size: .medium, relativeTo: .compound.headingLG)
                            .foregroundStyle(.compound.iconSecondary)
                    }
            }
        }
        .frame(width: 280, height: 280)
        .clipShape(Circle())
        .overlay {
            Circle()
                .trim(from: 0, to: min(recorderState.duration / RoundVideoMessage.maxDuration, 1))
                .stroke(.compound.iconAccentTertiary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct RoundVideoPreviewCircle: View {
    let url: URL
    let duration: TimeInterval
    let isUploading: Bool
    let onPlaybackStarted: () -> Void
    
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    
    private let progressTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                circle
                
                Text(DateFormatter.roundVideoElapsedFormatter.string(from: Date(timeIntervalSinceReferenceDate: duration)))
                    .font(.compound.bodyMDSemibold)
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { notification in
            guard let item = notification.object as? AVPlayerItem, item === player?.currentItem else { return }
            isPlaying = false
            progress = 0
            player?.seek(to: .zero)
        }
        .onReceive(progressTimer) { _ in
            guard isPlaying, let player, let itemDuration = player.currentItem?.duration.seconds, itemDuration > 0 else { return }
            progress = player.currentTime().seconds / itemDuration
        }
    }
    
    private var circle: some View {
        ZStack {
            if let player {
                RoundVideoPlayerView(player: player)
            } else {
                Circle().fill(.compound.bgSubtleSecondary)
            }
            
            if isUploading {
                ProgressView()
                    .tint(.white)
            } else if !isPlaying {
                CompoundIcon(\.playSolid, size: .medium, relativeTo: .compound.headingLG)
                    .foregroundStyle(.white)
                    .padding(13)
                    .background(.black.opacity(0.4), in: .circle)
            }
        }
        .frame(width: 280, height: 280)
        .clipShape(Circle())
        .overlay {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.compound.iconAccentTertiary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .contentShape(Circle())
        .onTapGesture {
            guard !isUploading, let player else { return }
            if isPlaying {
                player.pause()
                isPlaying = false
            } else {
                onPlaybackStarted()
                try? AVAudioSession.sharedInstance().setCategory(.playback)
                player.play()
                isPlaying = true
            }
        }
    }
}

/// Live camera feed for the recording circle.
struct RoundVideoCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer?.session = session
        view.previewLayer?.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) { }
    
    final class PreviewView: UIView {
        override static var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer? {
            layer as? AVCaptureVideoPreviewLayer
        }
    }
}

struct RoundVideoComposerOverlay_Previews: PreviewProvider, TestablePreview {
    static let recordingViewModel = ComposerToolbarViewModel.mock(mockMode: .recordRoundVideo)
    static let previewViewModel = ComposerToolbarViewModel.mock(mockMode: .previewRoundVideo(isUploading: false))
    static let uploadingViewModel = ComposerToolbarViewModel.mock(mockMode: .previewRoundVideo(isUploading: true))
    
    static var previews: some View {
        RoundVideoComposerOverlay(context: recordingViewModel.context)
            .previewDisplayName("Recording")
        RoundVideoComposerOverlay(context: previewViewModel.context)
            .previewDisplayName("Preview")
        RoundVideoComposerOverlay(context: uploadingViewModel.context)
            .previewDisplayName("Uploading")
    }
}
