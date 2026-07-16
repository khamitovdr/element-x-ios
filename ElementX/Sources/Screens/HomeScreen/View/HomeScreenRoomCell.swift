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

struct HomeScreenRoomCell: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.redactionReasons) private var redactionReasons
    
    let room: HomeScreenRoom
    var roomListActivityVisibility: RoomListActivityVisibility = .current
    let isSelected: Bool
    let mediaProvider: MediaProviderProtocol!
    let action: (HomeScreenViewAction) -> Void
    
    private let verticalInsets = 8.0 // TG-SKIN: Telegram row is more compact than Element's.
    private let horizontalInsets = 16.0
    
    var body: some View {
        Button {
            if let roomID = room.roomID {
                action(.selectRoom(roomIdentifier: roomID))
            }
        } label: {
            HStack(spacing: 10.0) { // TG-SKIN: tighter avatar-to-text gap.
                avatar
                
                content
                    .padding(.vertical, verticalInsets)
                    .rowDivider(horizontalInsets: horizontalInsets)
            }
            .padding(.horizontal, horizontalInsets)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(HomeScreenRoomCellButtonStyle(isSelected: isSelected))
        .accessibilityIdentifier(A11yIdentifiers.homeScreen.roomName(room.name))
        .accessibilityHidden(redactionReasons.contains(.placeholder) ? true : false)
    }
    
    @ViewBuilder
    private var avatar: some View {
        if dynamicTypeSize < .accessibility3 {
            RoomAvatarImage(avatar: room.avatar,
                            avatarSize: .room(on: .chats),
                            mediaProvider: mediaProvider)
                .dynamicTypeSize(dynamicTypeSize < .accessibility1 ? dynamicTypeSize : .accessibility1)
                .accessibilityHidden(true)
        }
    }
    
    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            footer
        }
        // Hide the normal content for Skeletons and overlay centre aligned placeholders.
        .opacity(redactionReasons.contains(.placeholder) ? 0 : 1)
        .overlay {
            if redactionReasons.contains(.placeholder) {
                VStack(alignment: .leading, spacing: 2) {
                    header
                    lastMessage
                }
            }
        }
    }
    
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            HStack(spacing: 4) {
                Text(room.name)
                    .lineLimit(1)
                
                if let statusEmoji = room.statusEmoji {
                    Text(String(statusEmoji))
                }
                
                // TG-SKIN: mute icon sits beside the name, not in the trailing badges.
                if room.badges.isMuteShown {
                    CompoundIcon(\.notificationsOffSolid, size: .custom(15), relativeTo: .compound.bodyLG)
                        .foregroundColor(.compound.iconTertiary)
                        .accessibilityLabel(L10n.a11yNotificationsMuted)
                }
            }
            .font(headerFont)
            .foregroundColor(.compound.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if let timestamp = room.timestamp {
                Text(timestamp)
                    .font(room.isHighlighted ? .compound.bodySMSemibold : .compound.bodySM)
                    .foregroundColor(room.isHighlighted ? .compound.textActionAccent : .compound.textSecondary)
            }
        }
    }
    
    // TG-SKIN: Telegram titles are always bold, regardless of read state.
    private var headerFont: Font {
        .compound.bodyLGSemibold
    }
    
    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Hidden text with 2 lines to maintain consistent height, scaling with dynamic text.
                Text(" \n ")
                    .lastMessageFormatting(hasFailed: false)
                    .hidden()
                    .environment(\.redactionReasons, []) // Always maintain consistent height
                
                HStack(alignment: .top, spacing: 4.0) {
                    switch room.lastMessageState {
                    case .sending:
                        CompoundIcon(\.time, size: .small, relativeTo: .compound.bodyMD)
                            .foregroundStyle(.compound.iconTertiary)
                            .offset(y: -1)
                            .accessibilityLabel(L10n.commonSending)
                    case .failed:
                        CompoundIcon(\.errorSolid, size: .small, relativeTo: .compound.bodyMD)
                            .foregroundStyle(.compound.iconCriticalPrimary)
                            .offset(y: -1)
                            .accessibilityHidden(true) // The last message contains the error.
                    case .none:
                        EmptyView()
                    }
                    
                    lastMessage
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if room.badges.callBadgeType == .voice {
                    CompoundIcon(\.voiceCallSolid, size: .xSmall, relativeTo: .compound.bodySM)
                        .accessibilityLabel(L10n.a11yNotificationsOngoingCall)
                }
                
                if room.badges.callBadgeType == .video {
                    CompoundIcon(\.videoCallSolid, size: .xSmall, relativeTo: .compound.bodySM)
                        .accessibilityLabel(L10n.a11yNotificationsOngoingCall)
                }
                
                if room.badges.isMentionShown {
                    mentionIcon
                }
                
                if room.badges.unreadCount > 0 || room.badges.isDotShown {
                    TelegramUnreadBadge(count: room.badges.unreadCount, isMuted: room.badges.isMuted)
                        .accessibilityLabel(L10n.a11yNotificationsNewMessages)
                } else if room.isFavourite {
                    // TG-SKIN: Telegram shows the pin only when no unread badge; favourites map to pins.
                    CompoundIcon(\.pin, size: .custom(15), relativeTo: .compound.bodyMD)
                        .foregroundColor(.compound.iconQuaternary)
                        .accessibilityLabel(L10n.commonFavourited)
                }
            }
            .foregroundColor(room.isHighlighted ? .compound.iconAccentTertiary : .compound.iconQuaternary)
        }
    }
    
    private var mentionIcon: some View {
        CompoundIcon(\.mention, size: .custom(15), relativeTo: .compound.bodyMD)
            .accessibilityLabel(L10n.a11yNotificationsNewMentions)
    }
    
    @ViewBuilder
    private var lastMessage: some View {
        if let displayedLastMessage = room.displayedLastMessage {
            Text(displayedLastMessage)
                .font(lastMessageFont)
                .lastMessageFormatting(hasFailed: room.lastMessageState == .failed)
        }
    }
    
    // TG-SKIN: Telegram previews are always regular weight, even when unread.
    private var lastMessageFont: Font {
        .compound.bodyMD
    }
}

struct HomeScreenRoomCellButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isSelected ? Color.compound.bgSubtleSecondary : Color.compound.bgCanvasDefault)
            .contentShape(Rectangle())
            .animation(isSelected ? .none : .easeOut(duration: 0.1).disabledDuringTests(), value: isSelected)
    }
}

private extension View {
    func lastMessageFormatting(hasFailed: Bool) -> some View {
        foregroundColor(hasFailed ? .compound.textCriticalPrimary : .compound.textSecondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Previews

import MatrixRustSDKMocks

struct HomeScreenRoomCell_Previews: PreviewProvider, TestablePreview {
    static let summaryProviderGeneric = RoomSummaryProviderMock(.init(state: .loaded(.mockRooms)))
    static let genericRooms = summaryProviderGeneric.roomListPublisher.value.compactMap { mockRoom(summary: $0) }
    
    static let summaryProviderForNotificationsState = RoomSummaryProviderMock(.init(state: .loaded(.mockRoomsWithNotificationsState)))
    static let notificationsStateRooms = summaryProviderForNotificationsState.roomListPublisher.value.compactMap { mockRoom(summary: $0) }
    
    static let lastMessageStateRooms = [makeRoom(lastMessageState: .sending), makeRoom(lastMessageState: .failed)]
    
    static let roomHeroRooms = [makeRoom(heroes: [.mockDan]), makeRoom(heroes: [.mockErin])]
    
    // TG-SKIN: badge states exercised by the Telegram-style pill/pin restyle.
    static let badgeStateRooms = [
        makeRoom(unreadNotificationsCount: 4, notificationMode: .allMessages), // unmuted count pill
        makeRoom(unreadMessagesCount: 12, unreadNotificationsCount: 0, notificationMode: .mute), // muted count pill (grey)
        makeRoom(unreadMessagesCount: 0, unreadNotificationsCount: 0, notificationMode: .allMessages, isMarkedUnread: true), // marked-unread empty pill
        makeRoom(unreadMessagesCount: 0, unreadNotificationsCount: 0, notificationMode: .allMessages, isFavourite: true) // favourite pin, no badge
    ]
    
    static var previews: some View {
        VStack(spacing: 0) {
            ForEach(genericRooms) { room in
                HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: MediaProviderMock(.init())) { _ in }
            }
            
            HomeScreenRoomCell(room: .placeholder(), isSelected: false, mediaProvider: MediaProviderMock(.init())) { _ in }
                .redacted(reason: .placeholder)
        }
        .previewDisplayName("Generic")
        
        VStack(spacing: 0) {
            ForEach(notificationsStateRooms) { room in
                HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: MediaProviderMock(.init())) { _ in }
            }
        }
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Notifications State")
        
        VStack(spacing: 0) {
            ForEach(lastMessageStateRooms) { room in
                HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: MediaProviderMock(.init())) { _ in }
            }
        }
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Last Message State")
        
        VStack(spacing: 0) {
            ForEach(roomHeroRooms) { room in
                HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: MediaProviderMock(.init())) { _ in }
            }
        }
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Room Heroes")
        
        VStack(spacing: 0) {
            ForEach(badgeStateRooms) { room in
                HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: MediaProviderMock(.init())) { _ in }
            }
        }
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Telegram Badges")
    }
    
    static func mockRoom(summary: RoomSummary) -> HomeScreenRoom? {
        HomeScreenRoom(summary: summary)
    }
    
    static func makeViewModel(roomSummaryProvider: RoomSummaryProviderProtocol) -> HomeScreenViewModel {
        let userSession = UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "John Doe", roomSummaryProvider: roomSummaryProvider))))
        
        return HomeScreenViewModel(userSession: userSession,
                                   selectedRoomPublisher: CurrentValueSubject<String?, Never>(nil).asCurrentValuePublisher(),
                                   appSettings: .volatile(),
                                   analyticsService: AnalyticsServiceMock(.init()),
                                   notificationManager: NotificationManagerMock(),
                                   userIndicatorController: UserIndicatorControllerMock())
    }
    
    static func makeRoom(lastMessageState: RoomSummary.LastMessageState? = nil,
                         heroes: [UserProfile] = [],
                         unreadMessagesCount: UInt = 2,
                         unreadMentionsCount: UInt = 0,
                         unreadNotificationsCount: UInt = 2,
                         notificationMode: RoomNotificationModeProxy? = .mute,
                         isMarkedUnread: Bool = false,
                         isFavourite: Bool = false) -> HomeScreenRoom {
        let name = if heroes.count == 1 {
            heroes[0].displayName ?? heroes[0].id
        } else {
            "Foundation and Empire"
        }
        let summary = RoomSummary(room: RoomSDKMock(),
                                  id: UUID().uuidString,
                                  joinRequestType: nil,
                                  name: name,
                                  isDirect: heroes.count == 1,
                                  isSpace: false,
                                  avatarURL: heroes.count == 1 ? nil : .mockMXCAvatar,
                                  heroes: heroes,
                                  activeMembersCount: 0,
                                  lastMessage: AttributedString("How do you see the Emperor then? You think he keeps office hours?"),
                                  lastMessageDate: .mock,
                                  lastMessageState: lastMessageState,
                                  unreadMessagesCount: unreadMessagesCount,
                                  unreadMentionsCount: unreadMentionsCount,
                                  unreadNotificationsCount: unreadNotificationsCount,
                                  notificationMode: notificationMode,
                                  canonicalAlias: "#foundation-and-empire:matrix.org",
                                  alternativeAliases: [],
                                  hasOngoingCall: false,
                                  activeCallIntent: nil,
                                  isMarkedUnread: isMarkedUnread,
                                  isFavourite: isFavourite,
                                  isTombstoned: false)
        
        return .init(summary: summary)
    }
}
