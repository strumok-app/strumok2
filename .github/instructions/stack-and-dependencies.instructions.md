---
description: 'Use when adding, removing or upgrading dependencies in pubspec.yaml, choosing packages, or pinning flutter_rust_bridge/media_kit versions. Mandatory stack and excluded packages.'
applyTo: '**/pubspec.yaml'
---

# Stack and dependencies

## Mandatory (must be used, must not be replaced)

| Concern | Package(s) | Notes |
|---------|-----------|-------|
| UI framework | Flutter (stable channel), Dart ≥ 3.8 | Material 3 only. |
| State management | `flutter_riverpod`, `riverpod_annotation`, dev: `riverpod_generator`, `build_runner` | Riverpod 3.x, code-gen style (`@riverpod`). No `provider`, `bloc`, `get_it`, `mobx`, `ChangeNotifierProvider`-style globals. |
| Video | `media_kit`, `media_kit_video`, `media_kit_libs_video` | The only playback engine. mpv properties are tuned via `NativePlayer.setProperty` (see spec-06). |
| Rust bridge | `flutter_rust_bridge` | Runtime must stay compatible with codegen `2.12.0` (see spec-02). |

## Optional dependencies policy

Everything else is optional. Before adding any package, check all of:

1. A listed feature actually needs it.
2. It supports **Android, Linux and Windows** (don't add packages that only work on mobile unless guarded and only used on Android).
3. It is actively maintained and has a permissive license.
4. A ~100-line in-house implementation would not be simpler.

Record the reason in the commit message (`deps: add X because ...`).

### Known-working choices from the legacy app (allowed, not required)

Use these only if you need the capability; they are proven on all target platforms:

| Capability | Proven package |
|-----------|----------------|
| Firebase Auth + Realtime DB on **Linux/Windows/Android** | `firebase_dart` (pure Dart; FlutterFire has no Linux support) |
| Google sign-in (Android) | `google_sign_in` |
| Google OAuth on desktop (loopback consent) | `googleapis_auth` |
| Routing | `auto_route` *(or `go_router`; pick one, do not mix)* |
| Key-value prefs | `shared_preferences` |
| Local document DB | `sembast` *(or `drift`/`sqlite3`)* |
| Paths / folder picker | `path_provider`, `file_selector` |
| Desktop window / PiP window | `window_manager` |
| Android TV detection, ABI detection | `device_info_plus` |
| Android background downloads | `flutter_foreground_task` |
| Keep screen on / brightness / volume (Android) | `wakelock_plus`, `screen_brightness`, `volume_controller` |
| Image caching | `cached_network_image` |
| JSON models | `json_serializable` + `json_annotation` |
| Value equality | `equatable` *(or Dart records / `freezed`)* |
| HTTP | `http` API backed by `http2` through our `AlpnHttpClient` (`lib/core/network/`: HTTP/2 via ALPN with per-origin multiplexing, HTTP/1.1 fallback via `IOClient`); single shared client, see `architecture-and-state` instructions. Pure Dart on purpose: native HTTP plugins break the second FlutterEngine of the download foreground service. Never use `http.Client()`/`dart:io` `HttpClient` directly outside `core/network` (HTTP/1.1 only). |
| Logging | `logging` |
| App version (self-update) | `package_info_plus` |
| Open URLs (Linux update link, OAuth consent) | `url_launcher` |

### Explicitly excluded

- Any AI/LLM SDK (`googleai_dart`, etc.).
- Crash/analytics SaaS (`sentry_flutter`, `firebase_analytics`, `firebase_crashlytics`).
- iOS/macOS/web-only plugins.
- Additional state-management libraries.
- Alternative video players (`video_player`, `better_player`, `fvp`, etc.).

## Version pinning

- Commit `pubspec.lock`.
- Pin `flutter_rust_bridge` Dart runtime to a version whose `kFlutterRustBridgeRuntimeVersion`
  works with codegen `2.12.0` modules (the legacy app ran runtime `2.13.0` with
  `forceSameCodegenVersion: false`). Do not bump the Rust-side codegen version.
- If you need a `media_kit` fork/override (e.g. for Android fMP4 seeking), document why in `pubspec.yaml`.
