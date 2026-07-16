# Telegram Skin — Design

**Date:** 2026-07-16
**Status:** Approved
**Goal:** Neutrino's UI/UX mimics Telegram iOS as closely as possible — intersecting features verbatim, Neutrino-only features styled in Telegram's visual language — while the fork keeps tracking upstream `element-hq/element-x-ios`.

## Context & constraints

- The vendored Telegram-iOS repo (`~/Telegram-iOS`) is **UIKit + AsyncDisplayKit**, not SwiftUI. Its components cannot be reused directly. It serves as a **precision reference**: exact colors, fonts, metrics, and geometry are transcribed from source instead of eyeballed from screenshots.
  - Palettes: `submodules/TelegramPresentationData/Sources/DefaultDayPresentationTheme.swift`, `DefaultDarkPresentationTheme.swift`
  - Bubble geometry: `submodules/TelegramPresentationData/Sources/ChatMessageBubbleImages.swift`
  - Chat list metrics: `submodules/ChatListUI/Sources/Node/ChatListItemNode.swift`
- **Upstream merges must stay survivable.** This rules out editing vendored `compound-ios` token files in place (upstream commits touch them) and rules out wholesale screen rewrites.
- Themes replicated: **Telegram Day** (iOS light mode) and **Telegram Night** (iOS dark mode). No theme picker.
- Ambition: **visual first, interactions later.** Interactions/animations are deferred phases chosen à la carte after the look is complete.
- Scope: **all user-facing surfaces.**
- Licensing: values and geometry are transcribed, not copied, from the GPLv2 repo into this AGPL fork. Copying individual asset files (icons, wallpaper pattern) is optional polish, acceptable for this personal, non-distributed fork.

## Architecture: layered skin (approved approach)

Three layers, cheapest first:

1. **Token override layer (zero upstream edits).** Compound ships a runtime override mechanism on both `CompoundColors` (SwiftUI) and `CompoundUIColors` (UIKit): `override(_ keyPath:with:)`. A fork-owned hook applies Telegram palette values to every semantic token at startup. Light/dark handled per-override with dynamic `UIColor { traits in … }` (the same pattern Compound uses internally for placeholder tokens).
2. **Fork-owned hero components.** The few components that define Telegram — bubble shape with tail, chat-list row internals, chat wallpaper, settings squircle icons — are new fork-owned SwiftUI files, integrated at one or two marked lines each.
3. **Per-screen spot fixes.** Views that hardcode colors or reach core tokens directly escape the override layer. Each screen phase carries its own short "escape list" found by grepping that screen's sources during the phase.

All in-place edits of upstream files carry a **`TG-SKIN` marker** (same convention as `FREE-ACCOUNT`).

## Phases

Each phase = one or more PRs (≤500 additions each), independently shippable and verifiable on device.

### Phase 0 — Reference extraction
One-time transcription of Telegram design values into a fork-owned Swift palette file. Every value keeps a comment naming its Telegram theme key (e.g. `chatList.unreadBadgeActiveFillColor`) for traceability. Covers Day + Night palettes, peer-name color palette, bubble metrics.

### Phase 1 — Global theme layer
- New `TelegramThemeHook` (under `ElementX/Sources/AppHooks/Hooks/`), registered in `AppHooks+Fork.setUp()`.
- Applies palette via `Color.compound.override(…)` + `UIColor.compound.override(…)` at startup.
- Compound's 6 decorative (avatar/sender-name) colors overridden with Telegram's peer-color palette.
- Typography: both apps use system SF; size/weight tweaks happen per-screen later, no font infrastructure needed.
- One unit test asserts overrides are applied — a Compound token keypath removed by an upstream bump fails loudly at compile/test time instead of silently reverting a color.

### Phase 2 — Tab bar restyle + Settings tab
- **All existing tabs stay: Chats, Spaces, Search.** No hiding. **Settings is added as a 4th tab** (Telegram UX: settings always one tap away).
- Existing `SettingsFlowCoordinator` mounts as the Settings tab root. The avatar-button entry point on the chat list is removed in Phase 3 (until then both entry points coexist harmlessly). Marked edit in `UserSessionFlowCoordinator.swift` (tabs array + settings mounting) — the one real structural edit; goes in the conflict table.
- Tab bar visuals: Telegram tint/appearance from the theme layer; SF Symbols nearest to Telegram's tab icons first, Telegram asset icons as optional polish.

### Phase 3 — Chat list
- `HomeScreenRoomCell.swift` restyled in place (marked) to Telegram's row: large round avatar (~60pt), bold name + right-aligned time on line 1, two-line gray preview, blue unread badge (gray when muted), pin indicator. Metrics/colors from `ChatListItemNode`.
- Nav chrome: "Chats" title, plain Telegram nav bar, compose button top-right wired to the existing start-chat flow; avatar button removed (settings now a tab); Element X "bloom" gradient removed.
- Filter chips restyled to Telegram folder-chip look; functionality unchanged.
- Swipe actions recolored/reordered to Telegram's palette; no new behaviors.

### Phase 4 — Chat screen (flagship; multiple sub-PRs)
- **Wallpaper:** fork-owned `TelegramChatBackground` view (Day/Night gradient wallpaper, transcribed values) behind the timeline, one marked integration line. Doodle-pattern asset copy = optional polish.
- **Bubbles:** fork-owned `TelegramBubbleShape` (SwiftUI `Shape`; corner radii + tail path from `ChatMessageBubbleImages.swift`). Element X's existing first/middle/last grouping maps to merged corners + tail-on-last. Outgoing: Day blue gradient / Night dark fill; incoming: white / dark gray. Integrated via marked edits in `Screens/Timeline/View/Style/` (`TimelineItemBubbleBackground`, `TimelineBubbleLayout`, `TimelineStyle`, `TimelineItemBubbledStylerView`).
- **Send info:** timestamp + read checkmarks inside the bubble, bottom-right (`TimelineItemSendInfoLabel` restyle).
- **Reactions:** Element X chips restyled to Telegram rounded pills.
- **Composer:** Telegram input bar skin — rounded "Message" field, paperclip left, mic/camera right. Existing hold-to-record voice + round-video features already match Telegram behavior; they only need the visual skin.
- **Room nav bar:** centered title + status subtitle ("N members" / presence), avatar on the right (restyle of room header view, marked).

### Phase 5 — Settings + profile
- Theme layer already restyles the grouped lists; deltas are: Telegram profile header (big centered avatar, name, username) on the settings root, and colored squircle row icons via a small fork-owned icon wrapper.
- Room details + user profile screens: same treatment (big header, grouped sections).

### Phase 6 — Onboarding + Neutrino-only screens + sweep
- Login, session verification, encryption reset, invites/knocks: no Telegram equivalent → Telegram visual language (centered content, big bold titles, blue primary buttons, grouped lists). Mostly falls out of the theme layer.
- Final escape-list sweep across all remaining screens.

### Phase 7+ — Interactions (deferred, à la carte)
Candidate list (not committed): Telegram-style context-menu preview, tab-switch animations, chat-open transition, scroll-to-bottom button behavior, date-header pill floating behavior. Swipe-to-reply already exists upstream.

## Testing & verification

- **Snapshots:** fork CI runs PreviewTests; each visual PR gets the `record-snapshots` label → Element CI re-records → approve its workflow runs (per fork playbook).
- **On-device:** each phase built to the user's iPhone and compared side-by-side with real Telegram — the actual fidelity gate.
- **Unit:** theme-hook override assertion test (Phase 1). Existing VM tests unaffected (visual-only changes).
- **Accessibility:** previews keep `TestablePreview` conformance so generated a11y tests keep running.

## Merge survival playbook

- `TG-SKIN` markers on every in-place edit.
- `docs/fork-slimming.md` gains a "Telegram skin" section: marker inventory, per-file conflict table (`UserSessionFlowCoordinator.swift`, `HomeScreenRoomCell.swift`, `Screens/Timeline/View/Style/*`, composer views, room header view), and a post-merge re-skin checklist mirroring the re-slim checklist.
- Fork-owned files (hook, palette, hero components) never conflict by construction.

## Risks

| Risk | Mitigation |
|------|------------|
| Upstream refactors of `Timeline/View/Style` (biggest conflict surface) | Localized marked edits + conflict table + re-skin checklist |
| `compound-design-tokens` bump renames token keypaths | Hook fails at compile time; override assertion test |
| Override layer can't reach hardcoded colors | Per-phase escape lists, final sweep in Phase 6 |
| Wallpaper/gradient fidelity approximate at first | Optional asset-copy polish item |
| Settings-tab edit conflicts on upstream navigation changes | Single marked block, documented in conflict table |

## Decisions log

- Copy-paste of Telegram components: **rejected** (AsyncDisplayKit, incompatible framework). Transcribe values instead.
- Editing vendored `compound-ios` in place: **rejected** (upstream touches it; recurring conflicts).
- Parallel Telegram UI kit + screen rewrites: **rejected** (permanent divergence).
- Hiding Spaces/Search tabs: **rejected by user** — all existing tabs stay, restyled.
- Settings: **4th tab** (user-approved).
- Themes: Day + Night only.
