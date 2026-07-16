# Telegram iOS Palette Reference (transcribed)

Exact values transcribed from the vendored Telegram-iOS checkout (`~/Telegram-iOS`) on 2026-07-16.
Sources:

- `submodules/TelegramPresentationData/Sources/DefaultDayPresentationTheme.swift`
- `submodules/TelegramPresentationData/Sources/DefaultDarkPresentationTheme.swift`
- `submodules/AvatarNode/Sources/AvatarNode.swift`
- `submodules/AccountContext/Sources/PeerNameColors.swift`

**Variant note:** `makeDefaultDayPresentationTheme(day:)` builds two light variants. Telegram's
out-of-box default is **Day Classic** (`day: false`; white incoming / `0xE1FFC7` green outgoing
bubbles on the pattern wallpaper). **Day** (`day: true`) has the blue-gradient outgoing bubbles on a
plain white background. Sections A–C are identical between the two except `chatList.checkmarkColor`
(Day `0x0088FF`, Day Classic `0x21C004`). The Neutrino skin uses **Day** bubbles (user-approved);
both are recorded here for Phase 4.

**Night accent note:** the base Night theme is monochrome (white accent). Stock Telegram's Night
appearance uses `defaultDarkColorPresentationTheme` = Night customized with accent `0x3E88F7`
(nav-badge fill becomes `0xEB5545`). The skin maps accent-ish tokens to `0x3E88F7` in dark mode.

Global: `defaultDayAccentColor` = `0x0088FF` · destructive light `0xFF3B30` / night `0xEB5545` ·
`defaultServiceBackgroundColor` = `0x000000 @ 0.2`.

`@` denotes alpha. "≈" marks values Telegram computes at runtime (mix/brightness), pre-resolved here.

## A. rootController

| field | Day / Day Classic | Night |
|---|---|---|
| navigationBar.buttonColor | 0x0088FF | 0xFFFFFF |
| navigationBar.disabledButtonColor | 0xD0D0D0 | 0x525252 |
| navigationBar.primaryTextColor | 0x000000 | 0xFFFFFF |
| navigationBar.secondaryTextColor | 0x787878 | 0xFFFFFF @ 0.5 |
| navigationBar.controlColor | 0x7E8791 | 0x767676 |
| navigationBar.accentTextColor | 0x0088FF | 0xFFFFFF |
| navigationBar.blurredBackgroundColor | 0xF2F2F2 @ 0.9 | 0x1D1D1D @ 0.9 |
| navigationBar.opaqueBackgroundColor | ≈0xF8F8F8 | ≈0x1A1A1A |
| navigationBar.separatorColor | 0xC8C7CC | 0x545458 @ 0.55 |
| navigationBar.badgeBackgroundColor | 0xFF3B30 | 0xFFFFFF (blue-accent variant: 0xEB5545) |
| navigationBar.badgeTextColor | 0xFFFFFF | 0x000000 |
| navigationBar.segmentedBackgroundColor | 0x000000 @ 0.06 | 0xFFFFFF @ 0.11 |
| navigationBar.segmentedForegroundColor | 0xF7F7F7 | 0xFFFFFF @ 0.36 |
| navigationBar.segmentedTextColor | 0x000000 | 0xFFFFFF |
| navigationBar.segmentedDividerColor | 0xD6D6DC | 0x505155 |
| navigationSearchBar.backgroundColor | 0xFFFFFF | 0x1C1C1D |
| navigationSearchBar.accentColor | 0x0088FF | 0xFFFFFF |
| navigationSearchBar.inputFillColor | 0x000000 @ 0.06 | 0xFFFFFF @ 0.1 |
| navigationSearchBar.inputTextColor | 0x000000 | 0xFFFFFF |
| navigationSearchBar.inputPlaceholderTextColor | 0x8E8E93 | 0x8F8F8F |
| navigationSearchBar.inputIconColor | 0x8E8E93 | 0x8F8F8F |
| navigationSearchBar.separatorColor | 0xC8C7CC | 0x545458 @ 0.55 |
| tabBar.backgroundColor | 0xF2F2F2 @ 0.9 | 0x1D1D1D @ 0.9 |
| tabBar.separatorColor | 0xB2B2B2 | 0x545458 @ 0.55 |
| tabBar.iconColor | 0x959595 | 0xFFFFFF |
| tabBar.selectedIconColor | 0x0088FF | 0xFFFFFF |
| tabBar.textColor | 0x000000 @ 0.8 | 0xFFFFFF |
| tabBar.selectedTextColor | 0x0088FF | 0xFFFFFF |
| tabBar.badgeBackgroundColor | 0xFF3B30 | 0xFFFFFF |
| statusBarStyle | .black | .white |

## B. list

| field | Day / Day Classic | Night |
|---|---|---|
| blocksBackgroundColor | 0xEFEFF4 | 0x000000 |
| plainBackgroundColor | 0xFFFFFF | 0x000000 |
| modalBlocksBackgroundColor | — | 0x1C1C1D |
| itemPrimaryTextColor | 0x000000 | 0xFFFFFF |
| itemSecondaryTextColor | 0x8E8E93 | 0x98989E |
| itemDisabledTextColor | 0x8E8E93 | 0x8F8F8F |
| itemAccentColor | 0x0088FF | 0xFFFFFF |
| itemHighlightedColor | 0x00B12C | 0x28B772 |
| itemDestructiveColor | 0xFF3B30 | 0xEB5545 |
| itemPlaceholderTextColor | 0xC8C8CE | 0x4D4D4D |
| itemBlocksBackgroundColor | 0xFFFFFF | 0x1C1C1D |
| itemModalBlocksBackgroundColor | — | 0x2C2C2E |
| itemHighlightedBackgroundColor | 0xE5E5EA | 0x313135 |
| itemBlocksSeparatorColor | 0xC8C7CC | 0x545458 @ 0.55 |
| itemPlainSeparatorColor | 0xC8C7CC | 0x545458 @ 0.55 |
| disclosureArrowColor | 0xBAB9BE | 0xFFFFFF @ 0.28 |
| sectionHeaderTextColor | 0x6D6D72 | 0x8D8E93 |
| freeTextColor | 0x6D6D72 | 0x8D8E93 |
| freeTextErrorColor | 0xCF3030 | 0xCF3030 |
| freeTextSuccessColor | 0x26972C | 0x30CF30 |
| itemSwitchColors.frameColor | 0xE9E9EA | 0x39393D |
| itemSwitchColors.handleColor | 0xFFFFFF | 0x121212 |
| itemSwitchColors.contentColor | 0x35C759 | 0x67CE67 |
| itemCheckColors.fillColor | 0x0088FF | 0xFFFFFF |
| itemCheckColors.strokeColor | 0xC7C7CC | 0xFFFFFF @ 0.3 |
| itemCheckColors.foregroundColor | 0xFFFFFF | 0x000000 |
| controlSecondaryColor | 0xDEDEDE | 0xFFFFFF @ 0.5 |
| freeInputField.backgroundColor | 0xD6D6DC | 0x272728 |
| freeInputField.placeholderColor | 0x96979D | 0x98989E |
| mediaPlaceholderColor | 0xEFEFF4 | ≈0x333334 |
| scrollIndicatorColor | 0x000000 @ 0.3 | 0xFFFFFF @ 0.5 |
| pageIndicatorInactiveColor | 0xE3E3E7 | 0xFFFFFF @ 0.3 |
| itemInputField.backgroundColor | 0xF2F2F7 | 0x0F0F0F |

## C. chatList

| field | Day / Day Classic | Night |
|---|---|---|
| backgroundColor | 0xFFFFFF | 0x000000 |
| itemSeparatorColor | 0xC8C7CC | 0x545458 @ 0.55 |
| itemBackgroundColor | 0xFFFFFF | 0x000000 |
| pinnedItemBackgroundColor | 0xF7F7F7 | 0x1C1C1D |
| itemHighlightedBackgroundColor | 0xE5E5EA | 0x121212 |
| itemSelectedBackgroundColor | 0xE9F0FA | 0x191919 |
| titleColor | 0x000000 | 0xFFFFFF |
| secretTitleColor | 0x00B12C | 0x00B12C |
| dateTextColor | 0x8E8E93 | 0x8D8E93 |
| authorNameColor | 0x000000 | 0xFFFFFF |
| messageTextColor | 0x8E8E93 | 0x8D8E93 |
| messageDraftTextColor | 0xDD4B39 | 0xDD4B39 |
| checkmarkColor | Day 0x0088FF · Classic 0x21C004 | 0xFFFFFF |
| pendingIndicatorColor | 0x8E8E93 | 0xFFFFFF |
| failedFillColor | 0xFF3B30 | 0xEB5545 |
| muteIconColor | 0xA7A7AD | 0x8D8E93 |
| unreadBadgeActiveBackgroundColor | 0x0088FF | 0xFFFFFF (blue-accent: 0x3E88F7) |
| unreadBadgeActiveTextColor | 0xFFFFFF | 0x000000 |
| unreadBadgeInactiveBackgroundColor | 0xB6B6BB | 0x666666 |
| unreadBadgeInactiveTextColor | 0xFFFFFF | 0x000000 |
| reactionBadgeActiveBackgroundColor | 0xFF2D55 | 0xFF2D55 |
| pinnedBadgeColor | 0xB6B6BB | 0x767677 |
| pinnedSearchBarColor | 0xE5E5E5 | 0x272728 |
| regularSearchBarColor | 0xE9E9E9 | 0x272728 |
| sectionHeaderFillColor | 0xFFFFFF | 0x000000 |
| sectionHeaderTextColor | 0x6D6D72 | 0x8D8E93 |
| verifiedIconFillColor | 0x0088FF | 0xFFFFFF |
| onlineDotColor | 0x4CC91F | 0x4CC91F |
| storyUnseenColors | 0x34C76F → 0x3DA1FD | same |
| storySeenColors | 0xD8D8E1 | 0x48484A |

## D. chat.message

### Day (blue-gradient variant — the skin's choice)

- incoming: fill `[0xFFFFFF]` with wallpaper, **`[0xF1F1F4]` without**; highlightedFill 0xDADADE;
  primaryText 0x000000; secondaryText 0x525252 @ 0.6; link 0x004BAD; accentText 0x0088FF;
  fileTitle 0x0088FF; mediaPlaceholder ≈0xF2F2F2
- outgoing: fill **gradient `[0x57B2E0, 0x0088FF]`** (top→bottom); highlightedFill ≈0x3D7D9D;
  stroke clear; primaryText 0xFFFFFF; secondaryText 0xFFFFFF @ 0.65; link 0xFFFFFF;
  accentText/controls 0xFFFFFF; mediaPlaceholder 0x0077D9
- outgoingCheckColor 0xFFFFFF · freeform fill [0xE5E5EA] · serviceMessage fill 0xFFFFFF @ 0.8,
  text 0x8D8E93 · default wallpaper: plain `0xFFFFFF`

### Day Classic (Telegram's actual out-of-box default — recorded for reference)

- incoming: fill `[0xFFFFFF]`; highlightedFill 0xD9F4FF; stroke 0x000000 @ 0.2;
  primaryText 0x000000; secondaryText 0x525252 @ 0.6; link 0x004BAD; accentText 0x0088FF;
  fileTitle 0x0B8BED
- outgoing: fill `[0xE1FFC7]`; highlightedFill 0xBAFF93; primaryText 0x000000;
  secondaryText 0x008C09 @ 0.8; accentText 0x00A700; controls 0x3FC33B
- outgoingCheckColor 0x19C700 · serviceMessage fill 0x939FAB @ 0.5, text 0xFFFFFF
- default wallpaper: builtin pattern `fqv01SQemVIBAAAApND8LDRUhRU` @ intensity 50 over gradient
  `[0xDBDDBB, 0x6BA587, 0xD5D88D, 0x88B884]`

### Night

- `incomingBubbleAlpha` 0.9; incoming fill `[0x1D1D1D @ 0.9]`; highlightedFill 0xFFFFFF @ 0.35;
  primaryText 0xFFFFFF; secondaryText 0xFFFFFF @ 0.5; link 0xFFFFFF; mediaPlaceholder ≈0x2A2A2A
- outgoing: fill **gradient `[0x61BCF9, 0x0088FF]`**; highlightedFill 0x61BCF9;
  primaryText 0xFFFFFF; secondaryText 0xFFFFFF @ 0.5
- outgoingCheckColor 0xFFFFFF · freeform fill [0x1F1F1F] · serviceMessage fill 0x1F1F1F,
  text 0xFFFFFF · unreadBar fill 0x1B1B1B / text 0xFFFFFF
- default wallpaper: same pattern slug @ intensity −34 over `[0x598BF6, 0x7A5EEF, 0xD67CFF, 0xF38B58]`

### chat.inputPanel

| field | Day / Day Classic | Night |
|---|---|---|
| panelBackgroundColor | 0xF2F2F2 @ 0.9 | 0x1D1D1D @ 0.9 |
| panelSeparatorColor | 0xBEC2C6 | 0x545458 @ 0.55 |
| panelControlAccentColor | 0x0088FF | 0xFFFFFF |
| panelControlColor | 0x000000 | 0xFFFFFF |
| panelControlDestructiveColor | 0xFF3B30 | 0xFF3B30 |
| inputBackgroundColor | 0xFFFFFF @ 0.8 | ≈0x242424 @ 0.95 |
| inputStrokeColor | 0x000000 @ 0.1 | 0xFFFFFF @ 0.1 |
| inputPlaceholderColor | 0x000000 @ 0.4 | 0xFFFFFF @ 0.48 |
| inputTextColor | 0x000000 | 0xFFFFFF |
| inputControlColor | 0x000000 @ 0.5 | 0xFFFFFF @ 0.5 |
| actionControlFillColor | 0x0088FF | 0xFFFFFF |
| actionControlForegroundColor | 0xFFFFFF | 0x000000 |
| mediaRecordingDotColor | 0xED2521 | 0xEB5545 |

### chat.historyNavigation

Day: fill 0xF7F7F7, stroke 0xC8C7CC, foreground 0x88888D, badge 0x0088FF/white text.
Night: fill 0x1C1C1D, stroke 0x545458 @ 0.55, foreground 0xFFFFFF, badge white/black text.

## E. Peer / avatar palettes

**AvatarNode.gradientColors** (top→bottom, index = `peerID % 7`):

| # | name | gradient |
|---|---|---|
| 0 | red | 0xFF516A → 0xFF885E |
| 1 | orange | 0xFFA85C → 0xFFCD6A |
| 2 | violet | 0x665FFF → 0x82B1FF |
| 3 | green | 0x54CB68 → 0xA0DE7E |
| 4 | cyan | 0x4ACCCD → 0x00FCFD |
| 5 | blue | 0x2A9EF1 → 0x72D5FD |
| 6 | pink | 0xD669ED → 0xE0A2F3 |

Extras: grayscale [0xB1B1B1, 0xCDCDCD] · savedMessages [0x2A9EF1, 0x72D5FD].
Avatar initials are always white.

**PeerNameColors.defaultSingleColors** (sender-name colors; fallback index 5 blue; dark mode uses
the same values by default):

| key | color |
|---|---|
| 0 | 0xCC5049 red |
| 1 | 0xD67722 orange |
| 2 | 0x955CDB violet |
| 3 | 0x40A920 green |
| 4 | 0x309EBA cyan |
| 5 | 0x368AD1 blue |
| 6 | 0xC7508B pink |

`displayOrder`: [5, 3, 1, 0, 2, 4, 6] (blue, green, orange, red, violet, cyan, pink).
