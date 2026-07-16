//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// Telegram-style unread pill: 20pt tall, radius 10, 12pt semibold tabular digits,
/// white on the accent badge colour (grey when muted). A zero count renders an
/// empty 20pt circle (marked-unread). Metrics transcribed from ChatListItem.swift
/// + ChatListBadgeNode.swift in the vendored Telegram repo. TG-SKIN (fork-owned).
struct TelegramUnreadBadge: View {
    let count: Int
    let isMuted: Bool
    
    var body: some View {
        Text(count > 0 ? String(count) : "")
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.compound.textOnSolidPrimary)
            .padding(.horizontal, count > 9 ? 6 : 0)
            .frame(minWidth: 20)
            .frame(height: 20)
            .background(isMuted ? Color.compound.bgBadgeSecondary : .compound.bgBadgeDefault)
            .clipShape(Capsule())
    }
}
