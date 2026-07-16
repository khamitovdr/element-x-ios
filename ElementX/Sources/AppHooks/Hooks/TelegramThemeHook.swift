//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import CompoundDesignTokens
import SwiftUI

/// Fork customisation: re-skins the app to Telegram's Day/Night palette by
/// overriding Compound's semantic colour tokens at startup (AppCoordinator applies
/// the registered compound hook before building any UI). Raw values and their
/// Telegram source keys: TelegramPalette + the palette reference doc. Entries
/// marked `derived:` have no Telegram equivalent and are fair game for tuning.
/// See docs/fork-slimming.md (TG-SKIN).
struct TelegramThemeHook: CompoundHookProtocol {
    func override(colors: CompoundColors, uiColors: CompoundUIColors) {
        for mapping in Self.mappings {
            colors.override(mapping.color, with: Color(mapping.value))
            uiColors.override(mapping.uiColor, with: mapping.value)
        }
    }
    
    // @MainActor here and on `mappings` is compiler-required: KeyPath isn't Sendable and statics don't inherit type isolation.
    /// Restores Compound defaults. Test-only; production never unsets the theme.
    @MainActor func removeOverrides(colors: CompoundColors, uiColors: CompoundUIColors) {
        for mapping in Self.mappings {
            colors.override(mapping.color, with: nil)
            uiColors.override(mapping.uiColor, with: nil)
        }
    }
    
    private typealias P = TelegramPalette
    
    // swiftlint:disable:next large_tuple
    @MainActor private static let mappings: [(color: KeyPath<CompoundColorTokens, Color>, uiColor: KeyPath<CompoundUIColorTokens, UIColor>, value: UIColor)] = [
        // MARK: Text
        
        (\.textPrimary, \.textPrimary, P.dynamic(day: 0x000000, night: 0xFFFFFF)), // list.itemPrimaryTextColor
        (\.textSecondary, \.textSecondary, P.dynamic(day: 0x8E8E93, night: 0x98989E)), // list.itemSecondaryTextColor
        (\.textDisabled, \.textDisabled, P.dynamic(day: 0x8E8E93, night: 0x8F8F8F)), // list.itemDisabledTextColor
        (\.textActionAccent, \.textActionAccent, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // defaultDayAccentColor / dark accent
        (\.textActionPrimary, \.textActionPrimary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // rootController.navigationBar.buttonColor
        (\.textActionSuccess, \.textActionSuccess, P.dynamic(day: 0x26972C, night: 0x30CF30)), // list.freeTextSuccessColor
        (\.textOnSolidPrimary, \.textOnSolidPrimary, P.dynamic(day: 0xFFFFFF, night: 0xFFFFFF)), // inputPanel.actionControlForegroundColor (night: blue-accent variant, not monochrome Night's black)
        (\.textLinkExternal, \.textLinkExternal, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // list.itemAccentColor
        (\.textCriticalPrimary, \.textCriticalPrimary, P.dynamic(day: 0xFF3B30, night: 0xEB5545)), // list.itemDestructiveColor
        (\.textSuccessPrimary, \.textSuccessPrimary, P.dynamic(day: 0x26972C, night: 0x30CF30)), // list.freeTextSuccessColor
        (\.textInfoPrimary, \.textInfoPrimary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // derived: accent
        (\.textBadgeAccent, \.textBadgeAccent, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // derived: accent content on pale bgBadgeAccent (upstream pairs dark-on-pale)
        (\.textBadgeInfo, \.textBadgeInfo, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // derived: accent content on pale bgBadgeInfo
        
        // MARK: Text decorative (sender names) — Telegram peer-name colors, displayOrder minus pink
        
        (\.textDecorative1, \.textDecorative1, P.dynamic(day: 0x368AD1, night: 0x368AD1)), // PeerNameColors key 5 blue
        (\.textDecorative2, \.textDecorative2, P.dynamic(day: 0x40A920, night: 0x40A920)), // key 3 green
        (\.textDecorative3, \.textDecorative3, P.dynamic(day: 0xD67722, night: 0xD67722)), // key 1 orange
        (\.textDecorative4, \.textDecorative4, P.dynamic(day: 0xCC5049, night: 0xCC5049)), // key 0 red
        (\.textDecorative5, \.textDecorative5, P.dynamic(day: 0x955CDB, night: 0x955CDB)), // key 2 violet
        (\.textDecorative6, \.textDecorative6, P.dynamic(day: 0x309EBA, night: 0x309EBA)), // key 4 cyan
        
        // MARK: Canvas / subtle backgrounds
        
        (\.bgCanvasDefault, \.bgCanvasDefault, P.dynamic(day: 0xFFFFFF, night: 0x000000)), // chatList.backgroundColor
        (\.bgCanvasDefaultLevel1, \.bgCanvasDefaultLevel1, P.dynamic(day: 0xFFFFFF, night: 0x1C1C1D)), // list.itemBlocksBackgroundColor
        (\.bgCanvasDisabled, \.bgCanvasDisabled, P.dynamic(day: 0xEFEFF4, night: 0x1C1C1D)), // derived: blocksBackground
        (\.bgSubtlePrimary, \.bgSubtlePrimary, P.dynamic(day: 0xE5E5EA, night: 0x2C2C2E)), // list.itemHighlightedBackgroundColor / itemModalBlocksBackgroundColor
        (\.bgSubtleSecondary, \.bgSubtleSecondary, P.dynamic(day: 0xEFEFF4, night: 0x1C1C1D)), // list.blocksBackgroundColor / itemBlocksBackgroundColor
        (\.bgSubtleSecondaryLevel0, \.bgSubtleSecondaryLevel0, P.dynamic(day: 0xEFEFF4, night: 0x000000)), // list.blocksBackgroundColor
        (\.bgSubtleTertiary, \.bgSubtleTertiary, P.dynamic(day: 0xF7F7F7, night: 0x1C1C1D)), // chatList.pinnedItemBackgroundColor
        
        // MARK: Action backgrounds
        
        (\.bgActionPrimaryRest, \.bgActionPrimaryRest, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // accent (filled buttons)
        (\.bgActionPrimaryHovered, \.bgActionPrimaryHovered, P.dynamic(day: 0x0080F0, night: 0x3679DE)), // derived: accent darkened
        (\.bgActionPrimaryPressed, \.bgActionPrimaryPressed, P.dynamic(day: 0x0077D9, night: 0x2F6BC5)), // derived: accent darkened
        (\.bgActionPrimaryDisabled, \.bgActionPrimaryDisabled, P.dynamic(day: 0xD0D0D0, night: 0x525252)), // navigationBar.disabledButtonColor
        (\.bgActionSecondaryRest, \.bgActionSecondaryRest, P.dynamic(day: 0xFFFFFF, night: 0x1C1C1D)), // list.itemBlocksBackgroundColor
        (\.bgActionSecondaryHovered, \.bgActionSecondaryHovered, P.dynamic(day: 0xE5E5EA, night: 0x2C2C2E)), // derived
        (\.bgActionSecondaryPressed, \.bgActionSecondaryPressed, P.dynamic(day: 0xDADADE, night: 0x313135)), // derived: messageDay highlightedFill / itemHighlightedBackground
        
        // MARK: Accent backgrounds
        
        (\.bgAccentRest, \.bgAccentRest, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // accent
        (\.bgAccentHovered, \.bgAccentHovered, P.dynamic(day: 0x0080F0, night: 0x3679DE)), // derived
        (\.bgAccentPressed, \.bgAccentPressed, P.dynamic(day: 0x0077D9, night: 0x2F6BC5)), // derived
        (\.bgAccentSelected, \.bgAccentSelected, P.dynamic(day: 0xE9F0FA, night: 0x191919)), // chatList.itemSelectedBackgroundColor
        (\.bgAccentSubtle, \.bgAccentSubtle, P.dynamic(day: 0xD9EBFF, night: 0x1C2E4A)), // derived: pale accent
        
        // MARK: Critical / success / info backgrounds
        
        (\.bgCriticalPrimary, \.bgCriticalPrimary, P.dynamic(day: 0xFF3B30, night: 0xEB5545)), // destructive
        (\.bgCriticalHovered, \.bgCriticalHovered, P.dynamic(day: 0xE5352B, night: 0xD54C3E)), // derived
        (\.bgCriticalSubtle, \.bgCriticalSubtle, P.dynamic(day: 0xFFEBEA, night: 0x2D1210)), // derived: pale destructive
        (\.bgCriticalSubtleHovered, \.bgCriticalSubtleHovered, P.dynamic(day: 0xFFD6D4, night: 0x3E1B18)), // derived
        (\.bgSuccessRest, \.bgSuccessRest, P.dynamic(day: 0x35C759, night: 0x67CE67)), // list.itemSwitchColors.contentColor
        (\.bgSuccessHovered, \.bgSuccessHovered, P.dynamic(day: 0x2FB350, night: 0x5CBF5C)), // derived
        (\.bgSuccessPressed, \.bgSuccessPressed, P.dynamic(day: 0x28A046, night: 0x52B052)), // derived
        (\.bgSuccessSubtle, \.bgSuccessSubtle, P.dynamic(day: 0xE3F7E9, night: 0x122B12)), // derived: pale success
        (\.bgInfoSubtle, \.bgInfoSubtle, P.dynamic(day: 0xE5F2FF, night: 0x14233B)), // derived: pale accent
        
        // MARK: Badges
        
        (\.bgBadgeAccent, \.bgBadgeAccent, P.dynamic(day: 0xD9EBFF, night: 0x1C2E4A)), // derived: pale accent
        (\.bgBadgeCritical, \.bgBadgeCritical, P.dynamic(day: 0xFF3B30, night: 0xEB5545)), // navigationBar.badgeBackgroundColor
        (\.bgBadgeDefault, \.bgBadgeDefault, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // chatList.unreadBadgeActiveBackgroundColor
        (\.bgBadgePrimary, \.bgBadgePrimary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // chatList.unreadBadgeActiveBackgroundColor
        (\.bgBadgeSecondary, \.bgBadgeSecondary, P.dynamic(day: 0xB6B6BB, night: 0x666666)), // chatList.unreadBadgeInactiveBackgroundColor
        (\.bgBadgeInfo, \.bgBadgeInfo, P.dynamic(day: 0xD9EBFF, night: 0x1C2E4A)), // derived: pale accent (solid accent made iconInfoPrimary invisible on it)
        
        // MARK: Decorative backgrounds (avatars) — derived pastels of the peer-name colors
        
        (\.bgDecorative1, \.bgDecorative1, P.dynamic(day: 0xE1EEF8, night: 0x14293D)), // derived: pale blue
        (\.bgDecorative2, \.bgDecorative2, P.dynamic(day: 0xE3F2DE, night: 0x14300B)), // derived: pale green
        (\.bgDecorative3, \.bgDecorative3, P.dynamic(day: 0xF9EBDE, night: 0x3D2410)), // derived: pale orange
        (\.bgDecorative4, \.bgDecorative4, P.dynamic(day: 0xF7E5E4, night: 0x3A1917)), // derived: pale red
        (\.bgDecorative5, \.bgDecorative5, P.dynamic(day: 0xEFE7FA, night: 0x2B1C40)), // derived: pale violet
        (\.bgDecorative6, \.bgDecorative6, P.dynamic(day: 0xE0F0F5, night: 0x0F2D36)), // derived: pale cyan
        
        // MARK: Icons
        
        (\.iconPrimary, \.iconPrimary, P.dynamic(day: 0x000000, night: 0xFFFFFF)), // list.itemPrimaryTextColor
        (\.iconPrimaryAlpha, \.iconPrimaryAlpha, P.dynamic(day: 0x000000, night: 0xFFFFFF)), // list.itemPrimaryTextColor
        (\.iconSecondary, \.iconSecondary, P.dynamic(day: 0x8E8E93, night: 0x98989E)), // list.itemSecondaryTextColor
        (\.iconSecondaryAlpha, \.iconSecondaryAlpha, P.dynamic(day: 0x8E8E93, night: 0x98989E)), // list.itemSecondaryTextColor
        (\.iconTertiary, \.iconTertiary, P.dynamic(day: 0xA7A7AD, night: 0x8D8E93)), // chatList.muteIconColor
        (\.iconTertiaryAlpha, \.iconTertiaryAlpha, P.dynamic(day: 0xA7A7AD, night: 0x8D8E93)), // chatList.muteIconColor
        (\.iconQuaternary, \.iconQuaternary, P.dynamic(day: 0xBAB9BE, night: 0xFFFFFF, nightAlpha: 0.28)), // list.disclosureArrowColor
        (\.iconQuaternaryAlpha, \.iconQuaternaryAlpha, P.dynamic(day: 0xBAB9BE, night: 0xFFFFFF, nightAlpha: 0.28)), // list.disclosureArrowColor
        (\.iconDisabled, \.iconDisabled, P.dynamic(day: 0xC8C8CE, night: 0x4D4D4D)), // list.itemPlaceholderTextColor
        (\.iconAccentPrimary, \.iconAccentPrimary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // accent
        (\.iconAccentTertiary, \.iconAccentTertiary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // accent
        (\.iconCriticalPrimary, \.iconCriticalPrimary, P.dynamic(day: 0xFF3B30, night: 0xEB5545)), // destructive
        (\.iconSuccessPrimary, \.iconSuccessPrimary, P.dynamic(day: 0x26972C, night: 0x30CF30)), // list.freeTextSuccessColor
        (\.iconInfoPrimary, \.iconInfoPrimary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // derived: accent
        (\.iconOnSolidPrimary, \.iconOnSolidPrimary, P.dynamic(day: 0xFFFFFF, night: 0xFFFFFF)), // inputPanel.actionControlForegroundColor
        
        // MARK: Separators & borders
        
        (\.separatorPrimary, \.separatorPrimary, P.dynamic(day: 0xC8C7CC, night: 0x545458, nightAlpha: 0.55)), // list.itemBlocksSeparatorColor
        (\.separatorSecondary, \.separatorSecondary, P.dynamic(day: 0xE5E5EA, night: 0x2C2C2E)), // derived: lighter separator
        (\.borderDisabled, \.borderDisabled, P.dynamic(day: 0xC8C7CC, night: 0x545458, nightAlpha: 0.55)), // list.itemBlocksSeparatorColor
        (\.borderFocused, \.borderFocused, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // accent
        (\.borderInteractivePrimary, \.borderInteractivePrimary, P.dynamic(day: 0xC7C7CC, night: 0xFFFFFF, nightAlpha: 0.3)), // list.itemCheckColors.strokeColor
        (\.borderInteractiveSecondary, \.borderInteractiveSecondary, P.dynamic(day: 0xD6D6DC, night: 0x39393D)), // navigationBar.segmentedDividerColor / itemSwitchColors.frameColor
        (\.borderInteractiveHovered, \.borderInteractiveHovered, P.dynamic(day: 0xB6B6BB, night: 0x767677)), // derived
        (\.borderAccentPrimary, \.borderAccentPrimary, P.dynamic(day: 0x0088FF, night: 0x3E88F7)), // accent
        (\.borderAccentSubtle, \.borderAccentSubtle, P.dynamic(day: 0xB8DCFF, night: 0x28457A)), // derived: pale accent
        (\.borderCriticalPrimary, \.borderCriticalPrimary, P.dynamic(day: 0xFF3B30, night: 0xEB5545)), // destructive
        (\.borderCriticalHovered, \.borderCriticalHovered, P.dynamic(day: 0xE5352B, night: 0xD54C3E)), // derived
        (\.borderCriticalSubtle, \.borderCriticalSubtle, P.dynamic(day: 0xFFC7C4, night: 0x54221E)), // derived: pale destructive
        (\.borderSuccessPrimary, \.borderSuccessPrimary, P.dynamic(day: 0x26972C, night: 0x30CF30)), // list.freeTextSuccessColor
        (\.borderSuccessSubtle, \.borderSuccessSubtle, P.dynamic(day: 0xBFEBCC, night: 0x1E4A1E)), // derived: pale success
        (\.borderInfoSubtle, \.borderInfoSubtle, P.dynamic(day: 0xBFDFFF, night: 0x1F3A66)) // derived: pale accent
    ]
}
