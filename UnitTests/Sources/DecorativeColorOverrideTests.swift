//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI
import Testing

struct DecorativeColorOverrideTests {
    @Test
    func decorativeColorsReflectRuntimeOverrides() {
        // All six pairs get the same override so the assertion is independent
        // of which index the contentID hashes to.
        Color.compound.override(\.bgDecorative1, with: .red)
        Color.compound.override(\.bgDecorative2, with: .red)
        Color.compound.override(\.bgDecorative3, with: .red)
        Color.compound.override(\.bgDecorative4, with: .red)
        Color.compound.override(\.bgDecorative5, with: .red)
        Color.compound.override(\.bgDecorative6, with: .red)
        Color.compound.override(\.textDecorative1, with: .blue)
        Color.compound.override(\.textDecorative2, with: .blue)
        Color.compound.override(\.textDecorative3, with: .blue)
        Color.compound.override(\.textDecorative4, with: .blue)
        Color.compound.override(\.textDecorative5, with: .blue)
        Color.compound.override(\.textDecorative6, with: .blue)
        defer {
            Color.compound.override(\.bgDecorative1, with: nil)
            Color.compound.override(\.bgDecorative2, with: nil)
            Color.compound.override(\.bgDecorative3, with: nil)
            Color.compound.override(\.bgDecorative4, with: nil)
            Color.compound.override(\.bgDecorative5, with: nil)
            Color.compound.override(\.bgDecorative6, with: nil)
            Color.compound.override(\.textDecorative1, with: nil)
            Color.compound.override(\.textDecorative2, with: nil)
            Color.compound.override(\.textDecorative3, with: nil)
            Color.compound.override(\.textDecorative4, with: nil)
            Color.compound.override(\.textDecorative5, with: nil)
            Color.compound.override(\.textDecorative6, with: nil)
        }
        
        let decorative = Color.compound.decorativeColor(for: "@alice:branga.ru")
        #expect(decorative.background == .red)
        #expect(decorative.text == .blue)
    }
}
