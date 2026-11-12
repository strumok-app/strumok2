---
description: 'Use when planning work, picking the next milestone, or checking milestone scope (M0..M9) of the Strumok rewrite.'
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
