//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// The composer's dual-mode record button. Tap toggles between voice message and round
/// video mode; press-and-hold starts recording the active mode; while recording, tap stops.
struct MediaRecordingButton: View {
    @Environment(\.isEnabled) private var isEnabled
    
    let recordingMode: MediaRecordingMode
    let isRecording: Bool
    
    var toggleMode: (() -> Void)?
    var startRecording: (() -> Void)?
    var stopRecording: (() -> Void)?
    
    private let impactFeedbackGenerator = UIImpactFeedbackGenerator()
    
    private var idleIconColour: Color {
        guard isEnabled else { return .compound.iconDisabled }
        return Compound.supportsGlass ? .compound.iconPrimary : .compound.iconSecondary
    }
    
    var body: some View {
        icon
            .contentShape(.circle)
            .onTapGesture {
                impactFeedbackGenerator.impactOccurred()
                if isRecording {
                    stopRecording?()
                } else {
                    toggleMode?()
                }
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                guard !isRecording else { return }
                impactFeedbackGenerator.impactOccurred()
                startRecording?()
            }
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(.isButton)
    }
    
    @ViewBuilder
    private var icon: some View {
        if isRecording {
            CompoundIcon(\.stopSolid,
                         size: Compound.supportsGlass ? .medium : .small,
                         relativeTo: .compound.headingLG)
                .foregroundColor(.compound.iconOnSolidPrimary)
                .scaledPadding(Compound.supportsGlass ? 10 : 8, relativeTo: .compound.headingLG)
                .background(.compound.bgActionPrimaryRest, in: .circle)
                .compositingGroup()
        } else {
            CompoundIcon(idleIcon, size: .medium, relativeTo: .compound.headingLG)
                .foregroundColor(idleIconColour)
                .scaledPadding(Compound.supportsGlass ? 10 : 6, relativeTo: .compound.headingLG)
                .background {
                    if Compound.supportsGlass {
                        Circle().fill(.compound.bgSubtleSecondary)
                    }
                }
        }
    }
    
    private var idleIcon: KeyPath<CompoundIcons, Image> {
        switch recordingMode {
        case .voice:
            Compound.supportsGlass ? \.micOnSolid : \.micOn
        case .roundVideo:
            Compound.supportsGlass ? \.videoCallSolid : \.videoCall
        }
    }
    
    private var accessibilityLabel: String {
        if isRecording {
            return L10n.a11yVoiceMessageStopRecording
        }
        switch recordingMode {
        case .voice: return L10n.a11yVoiceMessageRecord
        case .roundVideo: return UntranslatedL10n.a11yVideoMessageRecordIos
        }
    }
    
    private var accessibilityHint: String {
        guard !isRecording else { return "" }
        switch recordingMode {
        case .voice: return UntranslatedL10n.a11yVoiceMessageSwitchToVideoIos
        case .roundVideo: return UntranslatedL10n.a11yVideoMessageSwitchToVoiceIos
        }
    }
}

struct MediaRecordingButton_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        HStack(spacing: 12) {
            MediaRecordingButton(recordingMode: .voice, isRecording: false)
            MediaRecordingButton(recordingMode: .roundVideo, isRecording: false)
            MediaRecordingButton(recordingMode: .roundVideo, isRecording: true)
            MediaRecordingButton(recordingMode: .roundVideo, isRecording: false)
                .disabled(true)
        }
    }
}
