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
1. Rust supplier modules: FRB codegen `2.13.0`, content hash `-1122641696`, API major `5`. Don't edit or regenerate
   the bindings except as a coordinated bundle-major bump → [spec-02](../docs/specs/spec-02-content-suppliers-ffi.md), skill `rust-supplier-bridge`.
2. Firebase collection items: exact RTDB path `/collection/{uid}/{itemKey}` and JSON schema
   → [spec-03](../docs/specs/spec-03-collection-and-firebase-sync.md), skill `firebase-collection-compat`.
3. TV pairing: existing cloud functions `generatecode` / `exchangecodefortoken` unchanged
   → [spec-04](../docs/specs/spec-04-auth-and-tv-pairing.md).

**Mandatory update mechanisms:** supplier library install/update (startup guard, hot swap) and in-app self-update
(APK installer, Windows installer, Linux link) → [spec-11](../docs/specs/spec-11-app-and-suppliers-updates.md).

**HLS TS dejunking:** some hosts disguise TS segments with junk prefixes (fake PNG/JPEG). One shared dejunker in
`lib/core/hls/` MUST be used both by the local proxy (playback of `hlsProxy` sources) and by HLS downloads (always)
→ [spec-12](../docs/specs/spec-12-hls-ts-dejunking.md).

**Application id:** `app.strumok` (new app, side by side with legacy `app.cloud_hook`)
→ [spec-10](../docs/specs/spec-10-build-config-and-secrets.md).

## Where things are

Agent guidance lives in `.github/`; canonical feature specifications live in `docs/specs/`.

| Path | Content |
|------|---------|
| `.github/instructions/*.instructions.md` | Engineering rules and spec entrypoints; auto-attached by `applyTo` globs, otherwise load by description. |
| `docs/specs/*.md` | Canonical feature specifications, linked from the relevant instruction entrypoints. |
| `.github/skills/<name>/SKILL.md` | Playbooks: `rust-supplier-bridge` (incl. reference Rust contract crate in `assets/`), `firebase-collection-compat`, `riverpod-feature`, `tv-focus-navigation`, `adaptive-video-controls`, `localization-strings`. |
| `.github/prompts/*.prompt.md` | `/implement-milestone`, `/acceptance-review`. |

[Specs](../docs/specs/): [01 shell & pages](../docs/specs/spec-01-app-shell-and-navigation.md) ·
[02 suppliers FFI](../docs/specs/spec-02-content-suppliers-ffi.md) ·
[03 collection & sync](../docs/specs/spec-03-collection-and-firebase-sync.md) ·
[04 auth & TV pairing](../docs/specs/spec-04-auth-and-tv-pairing.md) ·
[05 profiles](../docs/specs/spec-05-profiles-multi-tenancy.md) ·
[06 video player](../docs/specs/spec-06-video-player.md) ·
[07 manga reader](../docs/specs/spec-07-manga-reader.md) ·
[08 downloads & offline](../docs/specs/spec-08-downloads-and-offline.md) ·
[09 settings](../docs/specs/spec-09-settings.md) ·
[10 build & secrets](../docs/specs/spec-10-build-config-and-secrets.md) ·
[11 updates](../docs/specs/spec-11-app-and-suppliers-updates.md) ·
[12 HLS TS dejunking & proxy](../docs/specs/spec-12-hls-ts-dejunking.md).
[13 video upscaling](../docs/specs/spec-13-video-upscaling.md).
Plan: [roadmap](instructions/roadmap.instructions.md) · [acceptance](instructions/acceptance.instructions.md).

## Working agreement

- Read the relevant spec in `docs/specs/` before coding a feature. If ambiguous, follow legacy behavior and leave a `// SPEC:` note;
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
