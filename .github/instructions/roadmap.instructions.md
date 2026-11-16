---
description: 'Use when planning work, picking the next milestone, or checking milestone scope (M0..M9, video player stages M5.1..M5.8) of the Strumok rewrite.'
---

# Roadmap (milestones)

Each milestone ends with: analyzer clean, tests green, Linux + Android debug builds run, `FORCE_TV_MODE` smoke pass.

## M0 — Skeleton
- Flutter project for **android, linux, windows only** (`flutter create --platforms=android,linux,windows`).
- Copy `.github/skills/rust-supplier-bridge/assets/content_suppliers_rust/` → `packages/content_suppliers_rust/` (+ Dart side and
  `content_suppliers_api` from the legacy repo, spec-02), verify checksums; copy ARB files; set up `l10n.yaml`,
  lints, build_runner, CI (analyze + test).
- `DeviceClass` provider, theme, router with empty pages, shell layouts (bottom nav / side rail), account menu stub.
- Android manifest: leanback launcher, TV banner, PiP support, permissions; `applicationId app.strumok`
  (`flutter create --org app --project-name strumok`), registered in the existing Firebase project (spec-10).

## M1 — Suppliers + updates
- Supplier bundle install/update/hot-swap (spec-02 §2.4, spec-11 §11.1), startup guard, supplier settings sub-page.
- App self-update (spec-11 §11.2): version check, Android APK install via `install_apk` channel, Windows installer, Linux link.
- FFI smoke integration test with the dummy lib.

## M2 — Browse
- Home recommendations, Search (filters, parallel per-supplier paging, history), Details (video + manga).

## M3 — Collection (local) + Profiles
- Local repository, collection page, status/priority, progress model (spec-03 §3.3, §3.5).
- Profiles model, picker, manage page (spec-05) — local only.

## M4 — Auth + Sync
- Google sign-in (Android, desktop), Firebase per-profile apps, realtime sync & merge (spec-03 §3.4).
- TV pairing (generate + exchange) (spec-04 §4.3). Legacy cross-check (skill `firebase-collection-compat`).

## M5 — Video player
- Controller + media_kit backend + mpv config; desktop controls; mobile controls; TV controls.
- HLS core (spec-12): playlist parser, TS dejunker, local dejunking proxy for `hlsProxy` sources — with the legacy test cases.
- Subtitles, tracks, speed, equalizer, player settings.

M5 is delivered in the stages below, **in order**. Each stage meets the milestone bar (analyzer clean, tests green,
Linux + Android debug builds run), keeps the app runnable and lists what it defers, so nothing is stubbed.
M5.1–M5.2 are pure Dart and also unblock M8 (HLS downloads).

### M5.1 — HLS core: dejunker + playlist model (spec-12 §12.2, §12.6)
- `lib/core/hls/ts_dejunker.dart`: streaming, resumes the scan from the last checked offset, 2 MiB no-sync cap.
- `lib/core/hls/hls_playlist.dart`: parse master/media playlists (`EXT-X-STREAM-INF`, `EXT-X-KEY`, `EXT-X-BYTERANGE`,
  `EXT-X-MAP`, `EXT-X-MEDIA-SEQUENCE`), resolve relative URIs; reusable by the proxy and the downloader.
- Tests: every dejunker case of §12.6 with the packet generator; playlist fixtures (master, media, encrypted, byterange, fMP4).
- No UI. Deferred: proxy server, downloads.

### M5.2 — Local HLS proxy (spec-12 §12.4)
- `lib/core/hls/hls_proxy.dart`: `127.0.0.1` + ephemeral port, `/master`, `/stream`, `/segment`, playlist rewriting,
  local/dejunked `Range` handling, always a known `Content-Length`, hop-by-hop header filter, 400/upstream/502 errors.
- Upstream requests go through the shared `httpClientProvider` (the proxy *server* may use `dart:io`).
- Tests: all proxy cases of §12.6 against a local upstream test server.
- Deferred: wiring into playback (M5.3).

### M5.3 — Playback foundation (spec-06 §6.1–6.4)
- Deps: `media_kit`, `media_kit_video`, `media_kit_libs_video` (wakelock comes with media_kit_video's `Video`).
  `MediaKit.ensureInitialized()` in bootstrap;
  document the Linux `libmpv` runtime requirement in README.
- `domain/`: `PlayerState`, `Playlist` (sections, next/prev), start-position rule (§6.2.3), source choice by `currentSourceName`.
- `data/`: `VideoBackend` interface + `MediaKitVideoBackend` (mpv properties §6.3, `alang`/`vlang`, ~5 s ended tolerance,
  `hlsProxy` sources through the M5.2 proxy, proxy stopped on dispose).
- `PlayerController`: keepAlive while playing, request tokens (§6.2.7), error with **Retry** (resumes at last position)
  and **Change source**, default on-end = play next, persisted volume, wakelock while playing,
  progress via `features/collection/domain/progress.dart` (debounced + on pause/exit/item change).
- Player route replaces the placeholder: video surface created once per backend + minimal shared controls
  (play/pause, seek bar with buffered range, time, back, source selector, error view) operable by mouse, touch and
  D-pad (Select = play/pause, Back = exit).
- Tests: start-position and source-choice rules; controller with a fake backend (stale-token races, retry position,
  progress writes, end → next item).
- Deferred: device-specific controls, subtitles, tracks, speed, equalizer, player settings.

### M5.4 — Desktop controls (spec-06 §6.6)
- `controls/desktop/`: full keyboard map, hover show / auto-hide (cursor too), double-click + F/Enter/Esc fullscreen,
  scroll on volume, prev/next, playlist panel (grouped by section, `P`).
- Dep: `window_manager` (fullscreen now, compact PiP window in M6).
- Shared widgets extracted for reuse: `seek_bar`, `source_selector`, `playlist_panel`.
- Tests: one widget test per hotkey against the fake backend; auto-hide timing.

### M5.5 — Mobile controls (spec-06 §6.7)
- `controls/mobile/`: tap toggles controls, double-tap left/right accumulating ±10 s, horizontal swipe seek, vertical drag brightness (left) /
  volume (right) with indicator, lock mode, forced landscape + immersive mode restored on exit, subtitle padding hook.
- Deps: `screen_brightness`, `volume_controller` behind `core/platform` interfaces (no-op off Android).
- Tests: gesture widget tests with fake brightness/volume implementations.
- Deferred: PiP button and auto-enter (M6).

### M5.6 — TV controls (spec-06 §6.8)
- `controls/tv/`: hidden state ←/→ accumulating seek preview (500 ms debounce → single seek), OK = play/pause,
  ↑/↓ show controls; visible state title-only top bar + bottom bar (seek bar; prev, play, next, source, episodes as
  labeled-on-focus pills) per spec-06 §6.5.1/§6.8; focusable seek bar (±10 s); Back hides controls, then exits.
- Tests: key-only widget tests in TV mode asserting focus moves and backend calls; manual session on a TV emulator.

### M5.7 — Subtitles and tracks (spec-06 §6.5)
- Supplier subtitles: fetch with source headers via the shared client; decode (BOM, UTF-8, Windows-1251 fallback) and
  WebVTT + SRT parsing in a separate isolate; tag sanitizing, cache per (supplier, id, item, name); Flutter overlay
  with size and ± offset. No subtitles through media_kit (mpv `sid=no`, no embedded tracks).
- "Off", persisted `currentSubtitleName`; audio track selector (subtitles panel) and video
  quality selector (introduces the Settings gear with its Quality page).
- Subtitles button (+ desktop `C`) opening the subtitles & audio side sheet in desktop, mobile and TV controls, placed
  first in the bottom-bar action group (spec-06 §6.5.1).
- Tests: parser fixtures (VTT, SRT, BOM, non-UTF-8, tags, malformed cues), cue lookup with offset.

### M5.8 — Speed, equalizer, player settings (spec-06 §6.5, spec-09 §5)
- Speed 0.5–2.0; 5-band equalizer via mpv `af` with presets (persisted `video_player_equalizer_bands`).
- Shuffle, on-end action, start-from (+ fixed seconds) as Settings (gear) pages next to Quality, Speed and
  Equalizer (side sheet pages, spec-06 §6.5.1), and the "Video player" section in Settings
  (floating-player switch arrives with M6, max parallel downloads with M8).
- Tests: `af` string builder, presets, settings persistence, shuffle/on-end playlist logic.

### M5 exit
- Acceptance "Video player" items except floating player / PiP (M6), verified on Linux, Windows build, Android phone
  and Android TV emulator; an `hlsProxy` source with junked TS plays and seeks; switching source keeps the position.

## M6 — Floating player + PiP
- In-app floating overlay; Android PiP via `strumok/pip`; desktop compact window.

## M7 — Manga reader
- All modes, preload, auto-crop, progress.

## M8 — Downloads + Offline
- Scheduler (parallel + sequential per show), Android foreground service, HLS download reusing the spec-12 dejunker, offline storage layout,
  offline items screen, offline mode.

## M9 — Polish & release
- Settings completeness, empty/error states, TV focus audit, l10n audit, performance (startup, scrolling), release builds.

## Optional (only if explicitly requested later)
- One-time import of legacy sembast local collection.
- PIN/kids profiles.
