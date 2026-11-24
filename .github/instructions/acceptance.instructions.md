---
description: 'Use when verifying a milestone or release: acceptance checklist for stack, compatibility, pages, player, collection, offline, updates, localization.'
---

# Acceptance checklist

## Stack & platforms
- [ ] Only Flutter + Riverpod + media_kit + flutter_rust_bridge are mandatory deps; every other dep justified (`stack-and-dependencies` instructions).
- [ ] No iOS/macOS/web folders or code paths.
- [ ] Android phone, tablet, Android TV, Linux, Windows builds run.

## Compatibility (blocking)
- [ ] Published `strumok_suppliers` bundle downloads, loads and serves search/details/sources/manga pages on Linux, Windows, Android (arm64 + x86_64 emulator).
- [ ] Bundle info JSON and file naming (`lib<name>_<version>.so` / `<name>_<version>.dll` in `<appSupport>/ffi`) as specified.
- [ ] Existing Firebase account: all legacy collection items appear with correct status, priority, current item, positions, source names.
- [ ] Item edited in the rewrite is shown correctly by the legacy app (and vice versa), including deletes.
- [ ] `positions` arriving as an array are parsed.
- [ ] TV pairing: code generated on phone (`generatecode`, Bearer ID token) logs in the TV (`exchangecodefortoken`, form `code`), TV then syncs the same collection.
- [ ] Android `applicationId` is `app.strumok`, registered in the same Firebase project (new `google-services.json`, SHA fingerprints added); Google sign-in returns the same Firebase uid as the legacy app for the same account.

## Updates (mandatory)
- [ ] Fresh install: startup guard installs the supplier bundle; shell appears without app restart.
- [ ] Newer compatible bundle is detected, downloaded and hot-swapped without restart; failed load keeps the old bundle.
- [ ] Incompatible bundle major is not installed and points to the app update.
- [ ] App update detected from `APP_VERSION_CHECK_URL`; Android (phone + TV) downloads APK and opens the system installer (unknown-sources permission flow handled); Windows runs the downloaded installer; Linux opens the download link.
- [ ] Update checks throttled and silent on failure at startup.

## Pages
- [ ] Home, Search, Collection, Details, Video player, Manga reader, Settings (+ Suppliers sub-page, Downloads, Profiles).
- [ ] Bottom nav < 450 dp, side rail ≥ 450 dp.

## Video player
- [ ] Separate desktop / mobile / TV controls; all key bindings & gestures from spec-06.
- [ ] Floating player (not on TV), corner snapping, return to full screen without re-buffering.
- [ ] PiP on Android (auto-enter, remote actions) and desktop (compact window); none on TV.
- [ ] `hlsProxy` sources with junked TS segments play and seek through the local proxy (spec-12).
- [ ] One shared TS dejunker used by both the proxy and the downloader; legacy dejunk/proxy test cases ported and green.
- [ ] Progress saved per spec-03 §3.3; resume rule (−60 s near end).
- [ ] Upscaling (spec-13, desktop only): presets visibly upscale in fullscreen on Linux (and Windows if supported per
  U0); setting hidden and shader assets absent on Android/TV builds; off restores native-size rendering; a failing
  shader falls back to off without a playback error.

## Collection
- [ ] Local collection works signed-out; realtime sync when signed-in; search by title; filters.
- [ ] Profiles: ≥2 profiles with different Google accounts on one device, switching without re-login, isolated collections.

## Offline
- [ ] Parallel downloads with global limit; episodes of one show download sequentially in order.
- [ ] Downloaded HLS from a host with junked TS segments produces a clean, playable, seekable file (spec-12 §12.5).
- [ ] Downloads continue in background on Android (foreground service notification).
- [ ] Offline mode: browse downloaded items, play video / read manga offline; progress synced later.

## Localization
- [ ] Ukrainian default, English available; no hard-coded strings; `untranslated-messages.json` empty.

## Quality
- [ ] `flutter analyze` 0 issues; `flutter test` green; compatibility fixtures present.
- [ ] Every screen fully operable with D-pad in `FORCE_TV_MODE`.
- [ ] No secrets in git.
