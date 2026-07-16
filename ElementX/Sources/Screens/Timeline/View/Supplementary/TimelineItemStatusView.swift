//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct TimelineItemStatusView: View {
    let timelineItem: EventBasedTimelineItemProtocol
    let adjustedDeliveryStatus: TimelineItemDeliveryStatus?
    @EnvironmentObject private var context: TimelineViewModel.Context
    
    /// TG-SKIN: mirrors `LiveLocationRoomTimelineItem.layout`'s `.hidden` condition
    /// (`TimelineItemSendInfoLabel.swift`) — while an outgoing live location share is
    /// active, the inline send info renders nothing, so this below-bubble badge needs
    /// to keep covering delivery feedback for that one case.
    private var hidesInlineSendInfo: Bool {
        (timelineItem as? LiveLocationRoomTimelineItem)?.content.isLive ?? false
    }
    
    var body: some View {
        mainContent
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if context.viewState.timelineKind == .pinned {
            // Do not display any status when is a pinned events timeline
            EmptyView()
        } else if context.viewState.showReadReceipts, !timelineItem.properties.orderedReadReceipts.isEmpty {
            readReceipts
        } else {
            deliveryStatusBadge
        }
    }
    
    @ViewBuilder
    var deliveryStatusBadge: some View {
        if !timelineItem.isOutgoing {
            // Incoming items never carry a delivery status — nothing to show here.
            EmptyView()
        } else if hidesInlineSendInfo {
            // TG-SKIN: carve-out for the live-location `.hidden` layout above — the inline
            // tick doesn't render for that case, so fall back to the below-bubble badge.
            switch adjustedDeliveryStatus {
            case .sending:
                TimelineDeliveryStatusView(deliveryStatus: .sending)
            case .sent, .none:
                TimelineDeliveryStatusView(deliveryStatus: .sent)
            case .sendingFailed:
                // Bubbles handle the case internally
                EmptyView()
            }
        } else {
            // TG-SKIN: the tick now lives inline next to the timestamp (see `TimelineItemSendInfoLabel`).
            EmptyView()
        }
    }
    
    var readReceipts: some View {
        TimelineReadReceiptsView(timelineItem: timelineItem)
            .environmentObject(context)
    }
}
