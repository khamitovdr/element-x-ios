//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct RoomListFilterView: View {
    let filter: RoomListFilter
    @Binding var isActive: Bool
    
    var body: some View {
        Toggle(isOn: $isActive) {
            Text(filter.localizedName)
        }
        .toggleStyle(FilterToggleStyle())
    }
}

// TG-SKIN: Telegram folder-style text tabs — accent text + underline when selected, no capsule background/stroke.
private struct FilterToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(configuration.isOn ? .compound.bodyMDSemibold : .compound.bodyMD)
            .foregroundColor(configuration.isOn ? .compound.textActionAccent : .compound.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .overlay(alignment: .bottom) {
                if configuration.isOn {
                    Capsule()
                        .fill(Color.compound.textActionAccent)
                        .frame(height: 3)
                        .padding(.horizontal, 8)
                }
            }
            .drawingGroup()
            // The button breaks the animation for some reason, so better to use the label directly with an onTapGesture
            .onTapGesture {
                configuration.isOn.toggle()
            }
    }
}

// MARK: - Previews

struct RoomListFilterView_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        RoomListFilterView(filter: .people, isActive: .constant(false))
        RoomListFilterView(filter: .people, isActive: .constant(true))
    }
}
