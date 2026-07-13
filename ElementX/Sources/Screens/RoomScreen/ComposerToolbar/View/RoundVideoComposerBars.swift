//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import Foundation
import SwiftUI

/// The slim in-toolbar bar shown while a round video is being recorded: pulsing red
/// dot + elapsed time. The camera itself is in the overlay above the timeline.
struct RoundVideoRecordingStatusBar: View {
    @ObservedObject var recorderState: RoundVideoRecorderState
    
    @State private var isDotVisible = true
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.compound.iconCriticalPrimary)
                .frame(width: 8, height: 8)
                .opacity(isDotVisible ? 1 : 0.3)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).disabledDuringTests(), value: isDotVisible)
                .onAppear { isDotVisible = false }
            
            Text(DateFormatter.roundVideoElapsedFormatter.string(from: Date(timeIntervalSinceReferenceDate: recorderState.duration)))
                .lineLimit(1)
                .font(.compound.bodySMSemibold)
                .foregroundColor(.compound.textSecondary)
                .monospacedDigit()
            
            Spacer()
            
            Text(UntranslatedL10n.commonVideoMessageIos)
                .font(.compound.bodySM)
                .foregroundColor(.compound.textSecondary)
        }
        .padding(.vertical, Compound.supportsGlass ? 14 : 8)
        .padding(.horizontal, Compound.supportsGlass ? 16 : 12)
        .background {
            RoundedRectangle(cornerRadius: Compound.supportsGlass ? 21 : 12)
                .fill(.compound.bgSubtleSecondary)
        }
    }
}

/// The slim in-toolbar bar shown while previewing a recorded round video.
struct RoundVideoPreviewStatusBar: View {
    let duration: TimeInterval
    
    var body: some View {
        HStack(spacing: 8) {
            Text(UntranslatedL10n.commonVideoMessageIos)
                .font(.compound.bodySM)
                .foregroundColor(.compound.textSecondary)
            
            Spacer()
            
            Text(DateFormatter.roundVideoElapsedFormatter.string(from: Date(timeIntervalSinceReferenceDate: duration)))
                .lineLimit(1)
                .font(.compound.bodySMSemibold)
                .foregroundColor(.compound.textSecondary)
                .monospacedDigit()
        }
        .padding(.vertical, Compound.supportsGlass ? 14 : 8)
        .padding(.horizontal, Compound.supportsGlass ? 16 : 12)
        .background {
            RoundedRectangle(cornerRadius: Compound.supportsGlass ? 21 : 12)
                .fill(.compound.bgSubtleSecondary)
        }
    }
}

private extension DateFormatter {
    static let roundVideoElapsedFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "mm:ss"
        return dateFormatter
    }()
}

struct RoundVideoComposerBars_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        VStack(spacing: 8) {
            RoundVideoRecordingStatusBar(recorderState: RoundVideoRecorderState())
            RoundVideoPreviewStatusBar(duration: 34)
        }
        .padding()
    }
}
