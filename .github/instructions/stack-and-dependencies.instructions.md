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
| Rust bridge | `flutter_rust_bridge` | Runtime must stay compatible with codegen `2.13.0` (see spec-02). |

## Optional dependencies policy

Everything else is optional. Before adding any package, check all of:

1. A listed feature actually needs it.
2. It supports **Android, Linux and Windows** (don't add packages that only work on mobile unless guarded and only used on Android).
3. It is actively maintained and has a permissive license.
4. A ~100-line in-house implementation would not be simpler.
5. Confirme any dependency you want to add or remove. Describe a reason for the change and get approval.

Record the reason in the commit message (`deps: add X because ...`).

### Explicitly excluded

- iOS/macOS/web-only plugins.
- Additional state-management libraries.
- Alternative video players (`video_player`, `better_player`, `fvp`, etc.).

## Version pinning

- Commit `pubspec.lock`.
- Pin `flutter_rust_bridge` Dart runtime to a version whose `kFlutterRustBridgeRuntimeVersion`
  works with codegen `2.13.0` modules (`forceSameCodegenVersion: false`). Bump the Rust-side codegen version
  only as part of a coordinated bundle-major change (as done for API 5).
- If you need a `media_kit` fork/override (e.g. for Android fMP4 seeking), document why in `pubspec.yaml`.
  Known candidate: a `media_kit_video` override that requests a GLES 3 context on Windows (ANGLE) for upscaling
  shaders — only if spec-13 stage U0 proves it is needed.
- Upscaling shaders (spec-13) are bundled assets, not packages; pin their upstream commits and licenses in
  `assets/shaders/README.md`.
