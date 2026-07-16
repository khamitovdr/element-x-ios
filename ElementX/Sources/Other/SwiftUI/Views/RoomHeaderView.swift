//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Compound
import SwiftUI

struct RoomHeaderView: View {
    struct DMRecipientDetails {
        var status: UserStatus?
        var verification: UserIdentityVerificationState?
    }
    
    let roomName: String
    var roomSubtitle: String?
    let roomAvatar: RoomAvatar
    var dmRecipientDetails = DMRecipientDetails()
    var roomHistorySharingState: RoomHistorySharingState?
    
    let mediaProvider: MediaProviderProtocol?
    
    let action: () -> Void
    
    var body: some View {
        if #available(iOS 26.0, *) {
            content
                // Not using a Button here so that we get our custom padding around the header. This also
                // helps fix a bug where the top pixel was being clipped during the push/pop animation as
                // the Button styling results in a view that is slightly taller than a bar item should be.
                .padding(6)
                .padding(.trailing, 6)
                .glassEffect(.regular.interactive())
                .roomHeaderAction(action)
        } else {
            // On iOS 18 and lower, the editor role causes an animation glitch with the back button whenever
            // you push a screen whilst the large title is visible on the room screen.
            content
                .roomHeaderAction(action)
        }
    }
    
    // TG-SKIN: the avatar moved to the trailing toolbar item, so this is just the
    // centered title/subtitle stack — no leading alignment or avatar here anymore.
    private var content: some View {
        HStack(spacing: 4) {
            VStack(alignment: .center, spacing: 0) {
                HStack(spacing: 8) {
                    Text(roomName)
                        .lineLimit(1)
                        .font(.compound.bodyMDSemibold)
                        .foregroundStyle(.compound.textPrimary)
                        .accessibilityIdentifier(A11yIdentifiers.roomScreen.name)
                    
                    if let statusEmoji = dmRecipientDetails.status?.displayed?.emoji {
                        Text(String(statusEmoji))
                            .font(.compound.bodyLG)
                            .foregroundStyle(.compound.textPrimary)
                    }
                }
                
                if let roomSubtitle {
                    Text(roomSubtitle)
                        .lineLimit(1)
                        .font(.compound.bodyXS)
                        .foregroundStyle(.compound.textSecondary)
                }
            }
            
            if let verificationState = dmRecipientDetails.verification {
                VerificationBadge(verificationState: verificationState, size: .xSmall, relativeTo: .compound.bodyMDSemibold)
            }
            
            if let historySharingIcon {
                CompoundIcon(historySharingIcon, size: .xSmall, relativeTo: .compound.bodyMDSemibold)
                    .foregroundStyle(.compound.iconInfoPrimary)
            }
        }
    }
    
    private var historySharingIcon: KeyPath<CompoundIcons, Image>? {
        switch roomHistorySharingState {
        case .none, .hidden: nil
        case .shared: \.history
        case .worldReadable: \.userProfileSolid
        }
    }
}

extension RoomHeaderView {
    // TG-SKIN: always automatic so the `.principal` toolbar item centers, Telegram-style.
    // `.editor` used to force leading alignment on iOS 26+; centering is now the point.
    static var toolbarRole: ToolbarRole {
        .automatic
    }
}

private extension View {
    func roomHeaderAction(_ action: @escaping () -> Void) -> some View {
        // Using a button stops it from getting truncated in the navigation bar
        contentShape(.rect)
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

struct RoomHeaderView_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 16) {
                makeHeader(avatarURL: nil)
                makeHeader(avatarURL: .mockMXCAvatar)
                
                makeHeader(avatarURL: .mockMXCAvatar, historySharingState: .shared)
                makeHeader(avatarURL: .mockMXCAvatar, historySharingState: .worldReadable)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                makeHeader(avatarURL: .mockMXCUserAvatar, verificationState: .verified)
                makeHeader(avatarURL: .mockMXCUserAvatar, verificationState: .verificationViolation)
                
                makeHeader(avatarURL: .mockMXCUserAvatar,
                           userStatus: .mockHoliday,
                           verificationState: .notVerified)
                makeHeader(avatarURL: .mockMXCUserAvatar,
                           userStatus: .mockCall,
                           verificationState: .verificationViolation)
                makeHeader(avatarURL: .mockMXCUserAvatar,
                           roomSubtitle: "Subtitle",
                           userStatus: .mockFocussing,
                           verificationState: .verified)
                
                makeHeader(avatarURL: .mockMXCUserAvatar,
                           roomSubtitle: "Subtitle",
                           verificationState: .verified)
                
                makeHeader(avatarURL: .mockMXCUserAvatar,
                           userStatus: .mockHoliday,
                           verificationState: .verified,
                           historySharingState: .shared)
                makeHeader(avatarURL: .mockMXCUserAvatar,
                           verificationState: .verificationViolation,
                           historySharingState: .worldReadable)
            }
        }
        .previewLayout(.sizeThatFits)
    }
    
    @ViewBuilder
    static func makeHeader(avatarURL: URL?,
                           roomSubtitle: String? = nil,
                           userStatus: UserStatus? = nil,
                           verificationState: UserIdentityVerificationState? = nil,
                           historySharingState: RoomHistorySharingState? = nil) -> some View {
        let roomName = verificationState == nil ? "Some Room Name" : "Some User Name"
        RoomHeaderView(roomName: roomName,
                       roomSubtitle: roomSubtitle,
                       roomAvatar: .room(id: "1",
                                         name: roomName,
                                         avatarURL: avatarURL),
                       dmRecipientDetails: .init(status: userStatus, verification: verificationState),
                       roomHistorySharingState: historySharingState,
                       
                       mediaProvider: MediaProviderMock(.init())) { }
    }
}
