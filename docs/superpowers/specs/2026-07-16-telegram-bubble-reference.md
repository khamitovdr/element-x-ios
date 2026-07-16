# Telegram Bubble Geometry Reference (transcribed)

Transcribed from the vendored Telegram-iOS checkout on 2026-07-16. Sources:
`submodules/TelegramPresentationData/Sources/ChatMessageBubbleImages.swift`,
`submodules/ChatMessageBackground/Sources/ChatMessageBackground.swift`,
`submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageItemCommon.swift`,
`ChatMessageBubbleItemNode.swift`, `PresentationThemeEssentialGraphics.swift`,
`WallpaperBackgroundNode.swift`.

## Corner radii

- Default setting: `mainRadius = 16`, `auxiliaryRadius = 8` (merged corners), NOT font-scaled.
- Media inside bubbles: radius − 1 (15 / 7).
- **Real on-screen semantics** (after un-flipping Telegram's internal render trick; verified against
  the media-corner path which has no flip). "Tail side" = trailing for outgoing (right), leading for
  incoming (left):

| position in group | tail-side corners | other corners | tail |
|---|---|---|---|
| standalone (single) | 16 / 16 | 16 / 16 | YES |
| first (merged below) | top 16, bottom **8** | 16 / 16 | no |
| middle | top **8**, bottom **8** | 16 / 16 | no |
| last (merged above) | top **8**, bottom 16 | 16 / 16 | YES |

- Tail present ⇒ tail-side bottom corner stays 16 (never reduced under a tail).

## Tail

- Threshold: full smooth tail only when radius ≥ 14 (default qualifies).
- Drawn in a 33×33 reference square at the bottom-trailing corner, then mirrored for incoming:
  - Bump: move to `(24, 24.5)` → quad-curve to `(37.5, 33)` control `(24, 33)` → quad-curve to
    `(51, 24.5)` control `(51, 33)` (an outward lens hugging the bubble's bottom edge; source rects:
    bottomEllipse `(24,16,27,17)`, topEllipse `(33,14,23,21)`).
  - The topEllipse (23×21 at x:33,y:14) is *subtracted* to carve the concave notch where the tail
    meets the bubble corner.
- Net visual: the tail extends ~6pt beyond the bubble body's trailing edge and ~17pt up from the
  bottom, with a concave upper edge. Rendered as a stretchable image (tail region is pixel-fixed).

## Insets & spacing

- Text bubble insets (default radius): **top 6+px, bottom 6−px, left/right 11**.
- Media insets: 2 all around (status inset 6 bottom/right). File bubbles: (15, 9, 15, 12).
- Bubble minimum size 40×35; edgeInset 3; stroke inset 1, border width ≈ px+0.25.
- Vertical spacing: **0 between merged bubbles**, 2+px otherwise.
- Merge criterion: same author/thread, < **10 min** apart, no inline keyboard (Element X uses 5 min
  + no-reactions — keep Element's, functional not visual).

## Max width

- ≤500pt list width: width − 36. >680pt (regular): 65% fill. Else 85% fill; minus edge/content
  insets and 38 avatar column. (Element X reserves 48pt on the far side — comparable; keep.)

## Outgoing gradient (Day variant; Night analogous)

- Day fill `[0x57B2E0 top → 0x0088FF bottom]`; Night `[0x61BCF9 → 0x0088FF]` (same with/without wallpaper).
- **Screen-anchored, not per-bubble**: the gradient bitmap spans the visible chat viewport height and
  each bubble samples the slice at its absolute on-screen position (`contentsRect` proportional to
  `rect/containerSize`), so lower bubbles are deeper blue and the colors shift as you scroll.
- Incoming Day (no wallpaper): flat `0xF1F1F4`, stroke clear. Night incoming: `0x1D1D1D` (drawn at 0.9 alpha over black).
