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
hr-seek=no                 
force-seekable=yes        
framedrop=no         
video-sync=audio
cache=yes                  
cache-secs=180            
demuxer-readahead-secs=180
demuxer-max-bytes=128M     
demuxer-max-back-bytes=32M 
cache-pause-wait=3
network-timeout=30
stream-lavf-o=reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_on_http_error=5xx,reconnect_delay_max=10
demuxer-lavf-o: append each reconnect option above + seg_max_retry=10   (use `change-list ... append` to keep media_kit defaults)
alang / vlang = "<userLanguage>,en"
```
Only exception: `framedrop=vo` while a desktop upscaler is active ([spec-13](spec-13-video-upscaling.instructions.md) F5).
Treat "ended" with a ~5 s tolerance near EOF. Do not reconnect on 4xx (expired links).

## 6.4 Junked HLS sources (`hlsProxy == true`) — MUST

Sources flagged `hlsProxy` serve MPEG-TS segments disguised with a junk prefix (fake PNG/JPEG etc.). The backend
MUST play them through the local HLS proxy, which dejunks every clear TS segment on the fly. The dejunk algorithm,
proxy endpoints, playlist rewriting and response rules are specified in
[spec-12](spec-12-hls-ts-dejunking.md) — implement them there, not in the player.

Player responsibilities only: start the proxy before opening the media, pass `http://127.0.0.1:<port>/master?url=…`
to media_kit together with the source headers, stop the proxy when the backend is disposed.

## 6.5 Features (all device classes unless noted)

- Play/pause, seek bar with buffered range, time labels, next/prev item, playlist panel (episodes grouped by section).
- Source (server) selector; subtitle selector (supplier subtitle sources); "subtitles off".
- Source and subtitle lists display the source's language alongside its description when provided; selection
  identity remains the unmodified description.
- Subtitles never go through media_kit/mpv: mpv runs with `sid=no` and the media_kit subtitle view is hidden; embedded
  subtitle tracks are not offered.
- Supplier subtitles: fetch with headers over the shared HTTP client, then decode (BOM-aware UTF-8/UTF-16, fallback
  Windows-1251) and parse **WebVTT, SRT, and ASS** in a **separate isolate**; sanitize tags; render as Flutter overlay;
  size setting; offset (± seconds, 0.5 s steps); cache parsed tracks per (supplier, id, item, name).
  ASS dialogue is rendered as plain text; styling, positioning, and vector drawings are not rendered.
- Audio track and video quality track selection.
- Playback speed (0.5–2.0, steps of 0.25); kept for the app session across items and titles, not persisted.
- 10-band equalizer via mpv `af` on VLC's default bands (60, 170, 310, 600, 1k, 3k, 6k, 12k, 14k, 16k Hz) plus a
  preamp applied before the bands; range ±20 dB for each, 1 dB steps. Persisted band lists of any other length
  (e.g. the earlier 5-band equalizer) read as flat. Presets set the preamp and every band (`preamp | bands`):
  Off `0 | 0×10`; Clear dialogue `0 | -2,-1,1,3,4,5,3,1,0,0`; Cinema `0 | 4,3,1,0,0,1,2,3,4,4`;
  Night `0 | -4,-2,0,2,3,4,3,0,-2,-3`; Action `0 | 6,5,3,0,-1,1,2,3,3,3`.
  Gains matching no preset (preamp included) show as "Custom".
  The controller hands the backend an `AudioEffects` object (`VideoBackend.setAudioEffects`); the media_kit backend
  builds the mpv filter itself (`data/mpv_audio_filter.dart`): `lavfi=[volume=volume=<dB>dB,
  equalizer=f=<Hz>:width_type=o:width=1:g=<dB>,…]` — the preamp when non-zero, then one one-octave peaking filter
  (VLC's width) per non-zero band; empty when flat.
  Equalizer page: a scrolling row of preset chips (a non-selectable "Custom" chip leads it while custom), a reset
  button in the page header, then a graphic equalizer — a preamp column, a divider, and 10 band columns over a
  ±20 dB grid with a smooth curve through the band gains and the active column's gain shown above the graph.
  Input: drag a column (the gain follows the pointer, clamped), mouse wheel over a column ±1 dB, double-tap resets
  it to 0; with a keyboard ↑/↓ change the focused column. Phone/tablet: haptic tick per dB, stronger at 0.
  TV: arrows move focus as usual; OK on a column enters adjust mode (↑/↓ ±1 dB, ←/→ move to the neighbor column
  staying in adjust mode, OK or Back leave it — Back then does not leave the page); a hint under the graph
  explains this.
  Two switches on the Equalizer page, persisted (`video_player_volume_normalization`,
  `video_player_dynamic_compression`, default off) and appended to the same `lavfi=[…]` chain after the bands:
  "Reduce loud sounds" → `acompressor=threshold=-18dB:ratio=3:attack=20:release=250:makeup=2`, then
  "Volume normalization" → `dynaudnorm=f=150:g=15`.
- Settings: shuffle mode; on-end action (`playNext` default / `playAgain` / `doNothing`); start-from
  (`fromRemembered` default / `fromBeginning` / `fromFixedPosition` + seconds, 10 s steps). Shuffle applies to
  the automatic advance at the end (`playNext`): a random other item; the Next button stays sequential.
- Upscaling with mpv GLSL shaders (desktop only, off by default) — specified in
  [spec-13](spec-13-video-upscaling.instructions.md); the §6.3 properties stay unchanged.
- Volume persisted (0–100, default 100). Keep screen awake while playing.
- Progress → collection per spec-03 §3.3; mark `complete` is user-driven (don't auto-complete).

### 6.5.1 Control placement (all device classes)

Buttons by frequency of use:

| Button | Contents | Placement |
|--------|----------|-----------|
| Play/pause, prev/next, seek bar | — | per device (below) |
| **Subtitles** (CC) | show/hide toggle: off when on, otherwise the last chosen subtitles of the session (the first when none) | own button when the item has supplier subtitles; CC icon on/off; tooltip "Show subtitles" / "Hide subtitles" |
| **Source** (server) | sources, current checked | own button; also "Change source" in the error view |
| **Episodes** | playlist grouped by section | own button |
| **Settings** (gear) | rows: Subtitles (with supplier subtitles: off + list, size and offset pinned below the scrolling list; choosing stays on the page), Audio (with several tracks), Quality (with several qualities), Upscaling (desktop, [spec-13](spec-13-video-upscaling.instructions.md)), Speed, Equalizer, Start from, When it ends → pages; Shuffle switch | own button, always shown |
| PiP, fullscreen, volume, lock | — | device-specific |

- Order is fixed everywhere: **subtitles → source → settings → episodes**, then window/mode buttons. Episodes is
  known as soon as the items load while settings appear with the media tracks: keeping episodes last (rightmost)
  means a late button never shifts it.
- A button with nothing to choose (one source, one episode, no subtitles) is **hidden**, not disabled.
- The top bar is identity only (back, title, episode) plus rare mode switches; actions live in the bottom bar.
- Panels open as side sheets from the trailing edge on every device, focused on the current choice. Settings: the
  root lists one row per setting with its current value; a row opens its page in place under a pinned back header;
  Back returns to the root (focus on that row), choosing a value returns too, the close button closes the sheet.

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
| S | open source selector |
| C | show/hide subtitles |
| `?`, H, F1 | show the keyboard shortcuts overlay (any key or click closes it, the key is swallowed); button tooltips also show their key, e.g. `Next (])` |

Layout: top bar = back, title, episode. Bottom bar = seek bar; row: prev, play, next, volume, time … subtitles,
source, settings, episodes, gap, PiP, fullscreen (far right).

Mouse: hover shows controls, auto-hide after inactivity (hide cursor too), double-click toggles fullscreen,
scroll on volume. PiP button (specs §6.9).

## 6.7 Mobile controls (phone/tablet)

- Layout (landscape): top bar = back, title, episode … PiP, lock (rare mode switches, away from the thumbs);
  center = prev, play/pause, next at the exact screen center; bottom row = time … subtitles, source, settings,
  episodes; seek bar flush with the bottom edge. All panels are side sheets.
- Tap toggles controls; double-tap left/right half → seek −10/+10 s (accumulating).
- Horizontal swipe → seek; a full-width swipe covers 120 s, the target time and offset are shown while swiping and
  the seek happens on release.
- Vertical drag: left half = screen brightness, right half = system volume, with on-screen indicator.
- **Lock** button: when locked only the unlock button is shown, gestures disabled.
- Force landscape + immersive full screen in the player; restore on exit.
- Subtitle padding moves up when controls are visible.
- PiP button; auto-enter PiP when user leaves the app while playing.

## 6.8 TV controls (Android TV — MUST be a separate implementation)

- No touch/hover assumptions; large, high-contrast focus indicators; controls auto-hide.
- Hidden state: ←/→ = seek −10/+10 s with **accumulating seek preview** (500 ms debounce, then single seek);
  OK/Enter/Select = play/pause; ↑/↓ = show controls.
- Visible state: top bar is title + episode only (no focusable items; the remote's Back does what a back button
  would). Bottom bar: focusable seek bar; one row prev, play, next, time … subtitles, source, settings, episodes.
  Buttons expand into a labeled pill (icon + text, inverted colors) while focused. Seek bar is focusable; ←/→ on it
  moves by 10 s units, ↓ returns to Play.
- Back: hide controls if visible; otherwise exit player.
- No floating player, no PiP, no fullscreen or volume buttons on TV.

## 6.9 Floating player (phone/tablet/desktop; setting, default **on**)

- When the user navigates back from the player, keep the video (playing or paused) in a mini player overlay above
  all routes (app root `Stack`). A failed session is closed instead.
- Width: 220 dp (mobile) / 420 dp (desktop), 16:9; snap to one of 4 corners after drag (default bottom-right);
  paddings: desktop 10/10, mobile 16 h / 32 v.
- Mobile controls: play/pause, close (stops playback), always visible; tap → reopen full-screen player.
- Desktop controls: the same as the desktop PiP window (§6.10), shown on hover/click and hidden after 2 s:
  prev / play-pause / next in the center, open full-screen player top-left, close (stops playback) top-right,
  progress at the bottom. Dragging still snaps to a corner.

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
