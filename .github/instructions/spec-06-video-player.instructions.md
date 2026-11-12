---
description: 'Use when working on the video player: media_kit backend, mpv properties, subtitles, desktop/mobile/TV controls, floating player, picture-in-picture. HLS proxy/dejunking is in spec-12.'
applyTo: 'lib/features/player/**, android/app/src/main/kotlin/**'
---

# Spec 06 — Video player

## 6.1 Architecture

```
VideoPlayerController (Riverpod notifier, UI-agnostic)
 ├─ playlist: SegmentedList<ContentMediaItem>, current item, source & subtitle selection
 ├─ VideoBackend (interface) ── MediaKitVideoBackend (only impl)
 ├─ progress writer → collection (spec-03 §3.3)
 └─ exposes: state stream (position, duration, buffering, playing, ended, error, tracks)
Controls (separate implementations, never one widget with if/else soup):
 ├─ DesktopControls   (mouse + keyboard)
 ├─ MobileControls    (touch, gestures)
 └─ TvControls        (D-pad only)
Overlays: FloatingPlayer (in-app mini player), PiP (Android native / desktop compact window)
```

- The controller survives route changes (keepAlive while playing) so the floating player and PiP reuse the
  same backend instance — **no re-buffering** when switching between full-screen, floating and PiP.
- Selection of controls by `DeviceClass` (`platforms-and-adaptive-ui` instructions). Desktop at tablet sizes still uses desktop controls.

## 6.2 Playback start

1. Load media items; pick `currentItem` from collection.
2. Resolve sources (lazy). Video candidates = sources with `kind == video`. Choose by `currentSourceName`
   (= `description`), fallback to first. No video → error "no sources".
3. Start position (setting "start from"): `fromBeginning` → 0; `fromRemembered` → stored position;
   `fromFixedPosition` → configured seconds. If `length > 0` and `start > length − 60` → `start −= 60`. Clamp ≥ 0.
4. Init backend with `link`, `headers`, `start`, preferred languages `{userLanguage, "en"}`, `hlsProxy`.
5. Apply persisted volume, equalizer, current playback speed.
6. On error: show error with **Retry** and **Change source**; retry resumes at last known position.
7. Race safety: every async step re-checks that item/source did not change and the controller is not disposed.

## 6.3 media_kit / mpv configuration — MUST (proven on slow CDNs)

```
hr-seek=no                 force-seekable=yes        framedrop=no         video-sync=audio
cache=yes                  cache-secs=180            demuxer-readahead-secs=180
demuxer-max-bytes=128M     demuxer-max-back-bytes=32M cache-pause-wait=3
network-timeout=30
stream-lavf-o=reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_on_http_error=5xx,reconnect_delay_max=10
demuxer-lavf-o: append each reconnect option above + seg_max_retry=10   (use `change-list ... append` to keep media_kit defaults)
alang / vlang = "<userLanguage>,en"
```
Treat "ended" with a ~5 s tolerance near EOF. Do not reconnect on 4xx (expired links).

## 6.4 Junked HLS sources (`hlsProxy == true`) — MUST

Sources flagged `hlsProxy` serve MPEG-TS segments disguised with a junk prefix (fake PNG/JPEG etc.). The backend
MUST play them through the local HLS proxy, which dejunks every clear TS segment on the fly. The dejunk algorithm,
proxy endpoints, playlist rewriting and response rules are specified in
[spec-12](spec-12-hls-ts-dejunking.instructions.md) — implement them there, not in the player.

Player responsibilities only: start the proxy before opening the media, pass `http://127.0.0.1:<port>/master?url=…`
to media_kit together with the source headers, stop the proxy when the backend is disposed.

## 6.5 Features (all device classes unless noted)

- Play/pause, seek bar with buffered range, time labels, next/prev item, playlist panel (episodes grouped by section).
- Source (server) selector; subtitle selector (supplier subtitle sources + embedded tracks); "subtitles off".
- External subtitles: fetch with headers, decode (UTF-8 with fallback), parse **WebVTT and SRT**, sanitize tags,
  render as Flutter overlay; size setting; offset (± seconds); cache parsed tracks per (supplier, id, item, name).
- Audio track and video quality track selection.
- Playback speed (0.5–2.0).
- 5-band equalizer via mpv `af` (bands 60, 230, 910, 4000, 14000 Hz; range ±12 dB) with presets:
  Reset `[0,0,0,0,0]`, Clear dialogue `[0,2,4,5,1]`, Cinema `[4,2,0,2,4]`, Night `[-3,0,3,4,-2]`, Action `[5,3,-1,1,3]`.
- Settings: shuffle mode; on-end action (`playNext` default / `playAgain` / `doNothing`); start-from
  (`fromRemembered` default / `fromBeginning` / `fromFixedPosition` + seconds).
- Volume persisted (0–100, default 100). Keep screen awake while playing.
- Progress → collection per spec-03 §3.3; mark `complete` is user-driven (don't auto-complete).

## 6.6 Desktop controls (keyboard map — MUST)

| Key | Action |
|-----|--------|
| Space, MediaPlayPause | play/pause |
| MediaPlay / MediaPause | play / pause |
| ← / → | seek −10 s / +10 s |
| Shift+← / Shift+→ | frame step back / forward |
| J / I | seek −60 s / +60 s |
| ↑ / ↓ | volume up / down |
| `]`, MediaTrackNext | next item |
| `[`, MediaTrackPrevious | previous item |
| F | toggle fullscreen; Enter → enter fullscreen; Esc → exit fullscreen |
| P | open playlist |

Mouse: hover shows controls, auto-hide after inactivity (hide cursor too), double-click toggles fullscreen,
scroll on volume. PiP button (specs §6.9).

## 6.7 Mobile controls (phone/tablet)

- Tap toggles controls; double-tap left/right half → seek −10/+10 s (accumulating).
- Vertical drag: left half = screen brightness, right half = system volume, with on-screen indicator.
- **Lock** button: when locked only the unlock button is shown, gestures disabled.
- Force landscape + immersive full screen in the player; restore on exit.
- Subtitle padding moves up when controls are visible.
- PiP button; auto-enter PiP when user leaves the app while playing.

## 6.8 TV controls (Android TV — MUST be a separate implementation)

- No touch/hover assumptions; large, high-contrast focus indicators; controls auto-hide.
- Hidden state: ←/→ = seek −10/+10 s with **accumulating seek preview** (500 ms debounce, then single seek);
  OK/Enter/Select = play/pause; ↑/↓ = show controls.
- Visible state: focus traverses top bar (back, title, source, subtitles, settings) and bottom bar (prev, play, next,
  seek bar, playlist). Seek bar is focusable; ←/→ on it moves by 10 s units.
- Back: hide controls if visible; otherwise exit player.
- No floating player and no PiP on TV.

## 6.9 Floating player (phone/tablet/desktop; setting, default **on**)

- When the user navigates back from the player while a video is playing, keep playing in a mini player
  overlay above all routes (app root `Stack`).
- Width: 220 dp (mobile) / 420 dp (desktop), 16:9; snap to one of 4 corners after drag (default bottom-right);
  paddings: desktop 10/10, mobile 16 h / 32 v.
- Controls: play/pause, close (stops playback). Tap → reopen full-screen player.

## 6.10 Picture-in-Picture

Common interface: `isSupported`, `isActive`, `enable/disable` (allow auto-enter), `updatePlayback(isPlaying,
hasPrev, hasNext, showSkipButtons, aspectRatio)`, `enter`, `exit`, action stream `{playPause, next, prev, dismissed}`.

**Android** — MethodChannel `strumok/pip` (keep names):
- Dart → native: `isSupported`, `enable`, `disable`, `update{isPlaying,hasPrev,hasNext,showSkipButtons,aspectRatio}`,
  `enter`, `exit`, `closeApp`.
- Native → Dart: `onPipModeChanged{active}`, `onAction{action: playPause|next|prev|dismissed}`.
- Use `PictureInPictureParams` with `RemoteAction`s (prev / play-pause / next) via a broadcast receiver;
  `setAutoEnterEnabled` on Android 12+, `onUserLeaveHint` fallback below.
- While in PiP render only the video surface (no controls, no subtitles padding).

**Desktop** — compact window via window manager: remember bounds, resize to long side 576 px with the
video aspect ratio, always-on-top, frameless-ish; restore previous bounds and state on exit. Serialize transitions.
