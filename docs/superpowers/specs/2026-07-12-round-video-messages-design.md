# Round Video Messages — Design

**Date:** 2026-07-12
**Repo:** element-x-ios fork (personal client for the `branga.ru` homeserver)
**Status:** Approved

## Overview

Add Telegram-style round video messages ("video notes") alongside the existing voice
messages. A round video is recorded in-app with the front camera, cropped to a square,
sent as a **standard `m.video` Matrix event**, and rendered by this fork as a circular
inline-playing bubble. Every other client (Element Web/Android, the mautrix-telegram
bridge) sees an ordinary square video. Files are deliberately small (~5–6 MB for a full-
length message).

## Goals

- Record and send round video messages from the composer, mirroring the voice-message UX.
- Render round videos as circles with inline tap-to-play playback (with sound).
- Full E2EE support — the user's server enables encryption for all rooms by default.
- Zero server changes and zero Rust SDK changes.
- Also render genuine Telegram video notes arriving via the mautrix-telegram bridge as circles.

## Non-goals (explicitly out of scope)

- Slide-to-lock / slide-to-cancel recording gestures.
- Autoplay-on-scroll (muted) playback.
- Circular rendering in the media gallery screen (`MediaEventsTimelineScreen`) — round
  videos appear there as normal videos.
- 2× playback, playback speed controls on the circle.
- Any Android/Web client work; any Matrix spec (MSC) work.

## Product decisions (locked)

| Decision | Choice |
|---|---|
| Entry point | Telegram-style dual-mode button: **tap toggles mic ↔ camera**, **hold records** the active mode |
| Max duration | **60 seconds** (auto-stop at cap) |
| Encoding | **400×400, H.264 High + AAC mono, ~700 kbps video / 64 kbps audio** ≈ 5–6 MB/min |
| Playback | Tap to play **inline with sound** + progress ring; tap to pause |
| Send flow | Stop → **preview** (replay / trash / send), same as voice messages |
| Round marker | **Filename convention** `round-video-<timestamp>.mp4` (Approach A) |
| Bridged Telegram notes | **Detected heuristically** and rendered round |

### Consequence flagged and accepted

Voice messages change from **tap-to-record** to **hold-to-record**, because tap now
toggles the mic/camera mode. This matches Telegram muscle memory.

## Why the filename marker (Approach A)

The Rust SDK's `Timeline.sendVideo` builds the `m.video` content itself and offers **no
way to attach custom JSON fields** (`UploadParameters` is a closed record). The
alternatives were rejected:

- **Raw send (`Room.sendRaw`) with a custom field:** the SDK exposes no
  `EncryptedFile`/encrypt-and-upload path, so media sent this way is plaintext-only —
  broken on a server where all rooms are encrypted by default.
- **Forking matrix-rust-sdk:** permanent Rust fork + custom xcframework builds to carry
  one cosmetic field. Not worth it.

The filename travels inside the (encrypted) `m.video` content, is exposed on receive via
`VideoMessageContent.filename`, and rides the fully supported send pipeline (encryption,
thumbnails, upload progress, retry). On a private invite-only server, spoofing is a
non-concern.

## Wire format

A round video is a standard `m.video` room message where:

- `filename` (and `body`) = `round-video-<yyyyMMdd-HHmmss>.mp4`
- `info`: `w == h == 400`, `duration ≤ 60_000` ms, `mimetype = video/mp4`, thumbnail +
  blurhash present, like any video sent by Element X.

No custom keys, no custom msgtype (Element X drops unknown msgtypes, and interop would
suffer).

## Detection (receive side)

In `RoomTimelineItemFactory`, where `m.audio` already branches on `voice != nil`, add a
pure function deciding round vs regular for `m.video`:

```
isRoundVideo(filename, width, height, durationSeconds) =
     (filename hasPrefix "round-video-" AND width == height)
  OR (width == height AND width > 0 AND width ≤ 480 AND 0 < durationSeconds ≤ 62)
```

- Branch 1: our own recordings (marker + square sanity check).
- Branch 2: heuristic for bridged Telegram video notes (400×400, ≤ 60 s). Accepted
  false positive: someone's genuinely square ≤480px short video renders in a circle
  (corners cropped); accepted as rare and harmless on a personal server.
- Missing `info` (no width/height) → not round.

## Recording UX

### Composer button (dual-mode)

- Replaces the current voice-message button behavior.
- **Tap:** toggle mic ↔ camera icon with haptic. Active mode persisted in `AppSettings`.
- **Press-and-hold:** start recording the active mode. Recording is *sticky* — lifting
  the finger does not stop or send; a stop control does. No release-to-send accidents.

### Recording overlay

Large circular live camera preview (~300 pt) centered over the chat, dimmed background:

- Front camera by default; flip button switches front/back. Front preview is mirrored
  and the recording matches the preview (Telegram behavior).
- Elapsed time + red recording dot; progress ring fills toward the 60 s cap.
- Stop button → preview state. Cancel/trash → discard, back to normal composer.
- Auto-stop at 60 s → preview state.
- Haptics on start/stop.

### Preview state

Same circle showing the recorded take (paused on first frame): tap to replay, composer
shows trash + send — mirroring `VoiceMessagePreviewComposer`. Send is instant: the file
is already final; no re-encode.

## Capture & encoding

New `RoundVideoRecorder` service (protocol + Sourcery mock, like `AudioRecorder`):

- `AVCaptureSession` with camera + mic inputs, `AVCaptureVideoDataOutput` +
  `AVCaptureAudioDataOutput`.
- Per-frame center-crop to square, scaled to **400×400**, written live via
  `AVAssetWriter` (`AVAssetWriterInputPixelBufferAdaptor`).
- Video: H.264 High profile, CABAC, ~700 kbps average. Audio: AAC, mono, 48 kHz,
  64 kbps. Container: `.mp4`.
- The recorded file **is** the sent file — no post-processing, no
  `MediaUploadingPreprocessor.processVideo` pass.
- Output to a dedicated temp dir (analog of `VoiceMessageCache`), file named
  `round-video-<yyyyMMdd-HHmmss>.mp4`; cleared like the voice-message cache.
- Reference implementation: Telegram-iOS checkout at
  `~/matrix_server/Telegram-iOS/submodules/Camera/Sources/` (`CameraOutput.swift`
  round-video branch: 400×400, H.264, 1 Mbps; `CameraRoundVideoFilter.swift` square
  crop; `VideoRecorder.swift` asset-writer pipeline). We use ~700 kbps for lighter files.
- `RoundVideoRecorderState` (analog of `AudioRecorderState`) publishes elapsed time and
  recording state to the overlay.

## Sending

1. Preview approved → generate thumbnail (first-frame JPEG + blurhash) reusing the
   existing preprocessor thumbnail helper (exposed or minimally extracted).
2. Build `VideoInfo` (duration, 400×400, mimetype, size, thumbnail info).
3. Call the existing `TimelineController.sendVideo(url:thumbnailURL:videoInfo:caption:...)`
   → `TimelineProxy.sendVideo` → Rust SDK (encrypts, uploads, retries). Caption always nil.
4. On success, delete the local recording; composer returns to `.default`.

Composer state machine gains `ComposerMode` cases `.recordRoundVideo(state:)` and
`.previewRoundVideo(...)`, alongside the voice cases, with matching
`ComposerToolbarViewModel` actions routed through `RoomScreenCoordinator` →
`TimelineViewModel` → `TimelineInteractionHandler` exactly like voice messages.

## Timeline display & playback

- New `RoundVideoRoomTimelineItem` (mirrors `VoiceMessageRoomTimelineItem`) carrying the
  existing `VideoRoomTimelineItemContent`; factory routes detected round videos to it.
- New `RoundVideoTimelineView`: circular clipped cell (blurhash → thumbnail), play icon,
  duration label; while playing, an inline `AVPlayer` layer plays **with sound** inside
  the circle with a progress ring on the rim. Tap toggles play/pause; playback ends →
  back to thumbnail.
- Media loading: download to file via the existing `MediaProvider` file cache, then
  `AVPlayer(url:)`.
- Single-playback rule: starting a round video pauses any other round video and detaches
  voice/audio playback via the existing `MediaPlayerProvider.detachAllStates`; starting a
  voice message pauses any playing round video. A small playback coordinator owns this.
- Long-press context menu (reply, forward, view source, …) unchanged.
- Outgoing local echoes render round via the same factory detection (filename is present
  in the local echo content).
- Replies/pinned/notifications describe it as a normal video (default SDK strings).

## Error handling

- **Camera/mic permission denied:** alert with link to Settings (same pattern as the
  existing mic permission flow); mode toggle still works, recording doesn't start.
- **Interruption (call, backgrounding, camera pressure):** stop the writer gracefully,
  land in preview with the partial take — same philosophy as voice recording.
- **Send failure:** SDK send-queue retry semantics for video apply unchanged; failed-send
  affordances identical to a normal video.
- **Playback load failure:** toast error; circle returns to thumbnail state.
- **Disk:** recordings capped ≤ ~6 MB; temp dir cleared on session teardown like the
  voice cache.

## Server

None required. Upload cap is 100 MB (≫ 6 MB); media is S3-backed with local hot cache;
all existing retention/cleanup applies since these are ordinary `m.video` events.

## Testing

- **Unit:** `isRoundVideo` detection (marker, heuristic bounds, missing-info, false-
  positive guards); recorder state transitions with the capture layer mocked behind its
  protocol; composer mode transitions (`ComposerToolbarViewModel`); factory tests that
  `m.video` events map to round vs regular items.
- **Snapshots:** `PreviewProvider` + `TestablePreview` previews for the new views in all
  main states (idle circle, recording overlay, preview, playing, error) → generated
  snapshot + accessibility tests.
- **Strings:** all new user-visible strings added to `Untranslated.strings` with `a11y_`
  labels for the toggle, record, stop, flip, and send controls.

## Key integration points (for the implementation plan)

- `ElementX/Sources/Screens/RoomScreen/ComposerToolbar/` — button, overlay views, modes.
- `ElementX/Sources/Screens/RoomScreen/ComposerToolbar/ComposerToolbarModels.swift` — `ComposerMode`.
- `ElementX/Sources/Screens/Timeline/TimelineInteractionHandler.swift` — record/send orchestration.
- `ElementX/Sources/Services/Timeline/TimelineItems/RoomTimelineItemFactory.swift` — detection + item building.
- `ElementX/Sources/Services/Timeline/TimelineController/TimelineController.swift` + `TimelineProxy.swift` — existing `sendVideo` (reused as-is).
- `ElementX/Sources/Services/Media/MediaUploadingPreprocessor.swift` — thumbnail/blurhash helper reuse.
- `ElementX/Sources/Services/VoiceMessage/` — the architecture template to mirror (`RoundVideo` sibling service dir).
- `ElementX/Sources/Services/MediaPlayer/MediaPlayerProvider.swift` — single-playback integration.
