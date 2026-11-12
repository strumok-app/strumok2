# Strumok — project instructions (rewrite)

Strumok is an ad-free media app for watching movies/series/anime and reading manga on Android (phone, tablet,
TV) and desktop (Linux, Windows). Content comes from **external Rust "supplier" modules** loaded at runtime via
`flutter_rust_bridge`. The user's library ("collection") is local-first and synced in realtime with
**Firebase Realtime Database**. This is a from-scratch rewrite: the legacy app defines behavior, not architecture.
**Compatibility contracts are not negotiable.**

## Hard constraints

**Mandatory stack:** Flutter (Dart 3, Material 3) · Riverpod (code-gen) · media_kit · flutter_rust_bridge.
Everything else is optional; add a package only when a listed feature needs it and justify it in the commit
(`deps: add X because ...`). Never add AI SDKs, Sentry/analytics SaaS, other state managers or other video players.

**Platforms:** Android phone/tablet/**Android TV**, **Linux**, **Windows** only. No iOS/macOS/web folders or code paths.

**Compatibility (acceptance-blocking):**
1. Rust supplier modules: FRB codegen `2.12.0`, content hash `-1122641696`, API major `4`. Never edit or regenerate
   the bindings → [spec-02](instructions/spec-02-content-suppliers-ffi.instructions.md), skill `rust-supplier-bridge`.
2. Firebase collection items: exact RTDB path `/collection/{uid}/{itemKey}` and JSON schema
   → [spec-03](instructions/spec-03-collection-and-firebase-sync.instructions.md), skill `firebase-collection-compat`.
3. TV pairing: existing cloud functions `generatecode` / `exchangecodefortoken` unchanged
   → [spec-04](instructions/spec-04-auth-and-tv-pairing.instructions.md).

**Mandatory update mechanisms:** supplier library install/update (startup guard, hot swap) and in-app self-update
(APK installer, Windows installer, Linux link) → [spec-11](instructions/spec-11-app-and-suppliers-updates.instructions.md).

**HLS TS dejunking:** some hosts disguise TS segments with junk prefixes (fake PNG/JPEG). One shared dejunker in
`lib/core/hls/` MUST be used both by the local proxy (playback of `hlsProxy` sources) and by HLS downloads (always)
→ [spec-12](instructions/spec-12-hls-ts-dejunking.instructions.md).

**Application id:** `app.strumok` (new app, side by side with legacy `app.cloud_hook`)
→ [spec-10](instructions/spec-10-build-config-and-secrets.instructions.md).

## Where things are

All agent material lives in `.github/`; application code never imports from it.

| Path | Content |
|------|---------|
| `.github/instructions/*.instructions.md` | Engineering rules and feature specs; auto-attached by `applyTo` globs, otherwise load by description. |
| `.github/skills/<name>/SKILL.md` | Playbooks: `rust-supplier-bridge` (incl. reference Rust contract crate in `assets/`), `firebase-collection-compat`, `riverpod-feature`, `tv-focus-navigation`, `adaptive-video-controls`, `localization-strings`. |
| `.github/prompts/*.prompt.md` | `/implement-milestone`, `/acceptance-review`. |

Specs: [01 shell & pages](instructions/spec-01-app-shell-and-navigation.instructions.md) ·
[02 suppliers FFI](instructions/spec-02-content-suppliers-ffi.instructions.md) ·
[03 collection & sync](instructions/spec-03-collection-and-firebase-sync.instructions.md) ·
[04 auth & TV pairing](instructions/spec-04-auth-and-tv-pairing.instructions.md) ·
[05 profiles](instructions/spec-05-profiles-multi-tenancy.instructions.md) ·
[06 video player](instructions/spec-06-video-player.instructions.md) ·
[07 manga reader](instructions/spec-07-manga-reader.instructions.md) ·
[08 downloads & offline](instructions/spec-08-downloads-and-offline.instructions.md) ·
[09 settings](instructions/spec-09-settings.instructions.md) ·
[10 build & secrets](instructions/spec-10-build-config-and-secrets.instructions.md) ·
[11 updates](instructions/spec-11-app-and-suppliers-updates.instructions.md) ·
[12 HLS TS dejunking & proxy](instructions/spec-12-hls-ts-dejunking.instructions.md).
Plan: [roadmap](instructions/roadmap.instructions.md) · [acceptance](instructions/acceptance.instructions.md).

## Working agreement

- Work milestone by milestone (roadmap). Each milestone must build and run on Linux and Android before the next.
- Re-read the relevant spec before coding a feature. If ambiguous, follow legacy behavior and leave a `// SPEC:` note;
  never silently change a compatibility contract.
- Branch UI by `DeviceClass` (phone/tablet/tv/desktop); every screen must work with D-pad only on TV.
- All user-visible text in `lib/l10n/app_uk.arb` (primary) and `app_en.arb`. No hard-coded strings.
- Keep the app runnable at every commit; no stubs that pretend features work.
- Never commit secrets (`secrets.env`, `google-services.json`, keystores, client secrets).

## Build and test

```bash
flutter pub get && dart run build_runner build -d && flutter gen-l10n
dart format . && flutter analyze && flutter test
flutter run -d linux --dart-define-from-file=secrets.env [--dart-define=FORCE_TV_MODE=true]
```

Done = spec `MUST`s verified, analyzer clean, tests green, Linux + Android debug builds succeed.
