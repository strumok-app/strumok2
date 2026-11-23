---
description: 'Use when working on video upscaling: mpv GLSL shaders (ArtCNN, RAVU, Anime4K, FSRCNNX, NNEDI3), VideoBackend upscaler API, render output sizing, shader assets/extraction, upscaling settings page.'
applyTo: 'lib/features/player/**, assets/shaders/**'
---

# Spec 13 — Video upscaling (mpv GLSL shaders)

Optional, user-selected upscaling of the video with mpv user shaders (`glsl-shaders`). **Desktop only (Linux,
Windows)**. Off by default. When it is off, playback MUST behave exactly as today (spec-06 §6.3).

## 13.1 Platform facts (media_kit_video 2.0.1) — why the rules below exist

| # | Fact | Where | Consequence |
|---|------|-------|-------------|
| F1 | Android also renders through mpv's GPU renderer (`vo=gpu`, `gpu-context=android`, `opengl-es=yes`, `hwdec=auto-safe`; software decoding on emulators). | `android_video_controller/real.dart` | Shaders are technically possible on Android. The limits there are GPU power and battery, especially on TV boxes. |
| F2 | Desktop uses `vo=libmpv` (render API, OpenGL), which is the same `gpu` renderer, so `glsl-shaders` works. On Linux, if GL init fails it falls back to **SW rendering**. | `native_video_controller/real.dart`, `linux/video_output.cc` | With SW rendering or HW acceleration off, upscaling is unsupported. |
| F3 | By default the desktop **texture size = the video's own size** (`VideoControllerConfiguration.width/height` = null), and Flutter scales the texture. | `linux/video_output.cc` (`video_output_get_width`) | In that state mpv never upscales and the shaders' `//!WHEN` conditions are false. While upscaling is on, the output MUST be resized to on-screen physical pixels (§13.4). |
| F4 | Both desktop embedders request a **GLES 2** context (`EGL_CONTEXT_CLIENT_VERSION 2`). Linux uses EGL; Windows uses ANGLE on D3D11. | `linux/video_output.cc`, `windows/angle_surface_manager.h` | Mesa and NVIDIA usually return a newer ES 3.x context. ANGLE likely returns exactly ES 2.0, and most prescalers fail there. Windows may need a `media_kit_video` override that requests ES 3 (verified in U0). Compute shaders need GL 4.3 / ES 3.1, so fragment variants are preferred (ArtCNN exception, §13.3). |
| F5 | The player runs `framedrop=no` + `video-sync=audio` (spec-06 §6.3, MUST, unchanged). | `media_kit_backend.dart` | A shader that is too heavy makes video lag behind audio. Cost labels and a performance hint (§13.7) are required. |
| F6 | The video view is built once per backend and moved between fullscreen, floating and PiP hosts. | spec-06 §6.1 | Output sizing lives inside the backend's view, so it follows every host. |

## 13.2 Scope

- **Desktop only: Linux + Windows** (`DeviceClass.desktop` platforms). On Android (phone, tablet, TV):
  - `supportedUpscalers` MUST be empty, so the setting is hidden (spec-06 §6.5.1: nothing to choose → hidden).
  - The shader store never runs.
  - The shader assets are not bundled (§13.3).
- Android phone/tablet support is a possible future extension that needs an explicit decision and a spec change
  (light presets only, after on-device benchmarks). **Never on Android TV.**
- Shaders are applied only to the main video. Subtitles are a Flutter overlay (spec-06 §6.5) and are not affected.

## 13.3 Shader catalog (curated, pinned, bundled)

Fragment-shader variants wherever upstream offers them (see F4). **Exception: ArtCNN is compute-only in every
upstream release** (`//!COMPUTE`, needs GL 4.3 / GLES 3.1), so its presets are offered only on platforms where U0
shows that compute works. Files live in `assets/shaders/<family>/`, shipped **unmodified**. Each one is pinned to an
upstream release or commit, with its license and sha256, in `assets/shaders/README.md`. The ids are stable,
persisted values. If a preset is removed later, its id must still resolve to "off".

| id | Family | Files | Cost | Anime hint |
|----|--------|-------|------|------------|
| `fsrcnnx_8` | FSRCNNX | `FSRCNNX_x2_8-0-4-1.glsl` | light | — |
| `fsrcnnx_16` | FSRCNNX | `FSRCNNX_x2_16-0-4-1.glsl` | medium | — |
| `ravu_lite_r4` | RAVU | `ravu-lite-ar-r4.hook` | light | — |
| `ravu_zoom_r3` | RAVU | `ravu-zoom-ar-r3.hook` (5.2 MB, embedded LUT) | medium | — |
| `nnedi3_64` | NNEDI3 | `nnedi3-nns64-win8x6.hook` | medium | — |
| `nnedi3_128` | NNEDI3 | `nnedi3-nns128-win8x6.hook` | heavy | — |
| `artcnn_c4f16` | ArtCNN | `ArtCNN_C4F16.glsl` (compute) | heavy | — |
| `artcnn_c4f16_ds` | ArtCNN | `ArtCNN_C4F16_DS.glsl` (compute) | heavy | — |
| `anime4k_a_fast` | Anime4K v4 | `Anime4K_Clamp_Highlights`, `Restore_CNN_M`, `Upscale_CNN_x2_M`, `AutoDownscalePre_x2`, `AutoDownscalePre_x4`, `Upscale_CNN_x2_S` | medium | yes |
| `anime4k_a_hq` | Anime4K v4 | official mode A (HQ) chain (`_VL`/`_L` variants) | heavy | yes |
| `anime4k_b_hq` | Anime4K v4 | official mode B (HQ) chain | heavy | yes |
| `anime4k_c_hq` | Anime4K v4 | official mode C (HQ) chain | heavy | yes |

- Presets that fail on a platform in U0 MUST be excluded from that platform's `supportedUpscalers`.
- **Licenses (verified):** Anime4K and ArtCNN are MIT. FSRCNNX, RAVU and NNEDI3 files are LGPL-3.0-or-later (per
  file headers; the FSRCNN-TensorFlow *repo* is GPL-3.0, but the released shaders are LGPL). Each family folder holds
  its `LICENSE`; `assets/shaders/GPL-3.0.txt` ships the GPL text that LGPL-3.0 builds on. Register all of them
  with `LicenseRegistry`.
- `.hook` (mpv-prescalers) is upstream's extension. mpv loads it like `.glsl`. Keep the upstream names.
- Anime4K chains match upstream's mpv templates (`md/Template/GLSL_Mac_Linux_{High,Low}-end/input.conf`), listed
  in `assets/shaders/README.md`.
- Total ≈ 7.2 MB, of which `ravu-zoom-ar-r3` is 5.2 MB (the r2 variant would be 3.0 MB). The catalog is kept
  as-is until U0 testing, then trimmed to what works and performs well.
- **Desktop-only bundling (MUST):** register every shader folder with a platform filter (Flutter
  `platforms:` asset key, supported by the pinned SDK 3.47.9; folder entries are not recursive), so Android builds don't include the shaders:
  ```yaml
  flutter:
    assets:
      - path: assets/shaders/anime4k/
        platforms: [linux, windows]
      # … the same for artcnn/, fsrcnnx/, ravu/, nnedi3/ and assets/shaders/GPL-3.0.txt
  ```
  Register the licenses with `LicenseRegistry` only on desktop. Android builds must not reference the missing
  assets.

## 13.4 Architecture

### Domain (pure) — `lib/features/player/domain/upscaling.dart`
```dart
enum UpscalerFamily { fsrcnnx, ravu, nnedi3, artcnn, anime4k }
enum UpscalerCost { light, medium, heavy }

@immutable
final class Upscaler {
  final String id;          // persisted, stable (§13.3)
  final UpscalerFamily family;
  final UpscalerCost cost;
  final bool forAnime;      // UI hint only
}

const upscalers = <Upscaler>[/* §13.3, in table order */];
Upscaler? upscalerById(String? id);   // unknown / removed / null → null (off)

/// Physical output size for mpv: the video fitted (contain) into the view. Returns null (native size,
/// no upscaling needed) when the fitted size is not larger than the source. The long side is capped
/// at [maxLongSide].
({int width, int height})? upscaleOutputSize(Size viewPx, Size videoPx, {int maxLongSide = 3840});
```

### `VideoBackend` additions — `data/video_backend.dart`
```dart
/// Upscalers this backend can run on this device; empty = unsupported (the setting is hidden).
List<Upscaler> get supportedUpscalers;

/// Null turns upscaling off (mpv's built-in scaling at the native texture size).
Future<void> setUpscaler(Upscaler? upscaler);

/// An upscaler failed (shader compile/link error, GPU limits). This is not a playback error and MUST NOT trigger
/// the Retry / Change source view.
Stream<Upscaler> get upscalerFailures;
```
The controller and the UI never see mpv properties or shader paths. This is the same pattern as
`setAudioEffects`/`mpv_audio_filter.dart`.

### Data
- `data/mpv_shaders.dart` (pure):
  - `shaderAssets`: upscaler id → list of asset paths, in order.
  - `mpvShaderCommands(paths)` → `['change-list','glsl-shaders','clr','']` followed by one
    `['change-list','glsl-shaders','append', path]` per file.
  - MUST NOT `set` a joined path list: the separator is `:` on Unix and `;` on Windows, and drive letters (`C:`)
    break the split.
- `data/shader_store.dart`: mpv needs real files, so this extracts one upscaler's assets on demand from
  `rootBundle` into `<AppPaths.support>/shaders/<catalogVersion>/`. Extraction is atomic (temp dir → rename →
  `.complete` marker) and idempotent. Directories of other catalog versions are deleted. The same code path is used on
  every platform.
- `MediaKitVideoBackend`:
  - `supportedUpscalers`: the catalog filtered by platform (Linux, Windows only) and by HW rendering (empty
    under SW rendering), minus presets excluded for the platform (§13.3).
  - `setUpscaler`: `await _configured` → extract → run `mpvShaderCommands` → enable/disable output sizing. Off runs
    `clr` and restores the native size (`setSize()` with nulls).
  - **Output sizing (F3):** `buildView()` wraps `Video` in a `LayoutBuilder` and uses `MediaQuery.devicePixelRatioOf`.
    While an upscaler is active, it calls `VideoController.setSize` with `upscaleOutputSize(...)`, debounced
    ~150 ms for window resize and fullscreen changes, and re-evaluates when the video size or aspect changes.
    When the result is null (floating player, PiP, view ≤ source), it restores the native size.
  - **Failure detection:** listen to `Player.stream.log` (`PlayerConfiguration.logLevel` ≥ warn). Error lines from
    the `vo`/`libmpv` prefixes about shader compile/link failures or unsupported features → `clr` shaders, restore
    native size, emit `upscalerFailures`. Keep the matcher small and test it with log lines recorded in U0. Log the
    GL version once at init (debug level).
  - `dispose` cancels the log subscription and the sizing debounce.

## 13.5 Settings and controller

- Preference key `video_player_upscaler` (string id; absent = off), constant `AppPreferences.videoPlayerUpscaler`
  (spec-09). Local only; never synced to Firebase (the collection contract is unchanged).
- `PlayerPreferences.upscaler` (`String?`) + `PlayerSettings.setUpscaler`.
- `PlayerController`:
  - `setUpscaler(Upscaler?)`: persist, then apply to the backend.
  - In `_createBackend()`: apply the persisted upscaler (next to the audio effects), only if it is in
    `supportedUpscalers`.
  - On `upscalerFailures`: persist off and show a localized message once. Playback continues.
  - Expose `supportedUpscalers` for the UI.

## 13.6 UI

- Player settings side sheet (spec-06 §6.5.1): new row **Upscaling right after Quality**. The root shows "Off" or the
  preset name.
- Page: "Off", then presets grouped by family. Each preset shows a cost badge (Light / Medium / Heavy) and an
  "Anime" hint where `forAnime`. A short help line notes that it uses the GPU and heavy presets need a strong
  graphics card. Choosing a value returns to the root (existing pattern).
- The row is hidden when `supportedUpscalers` is empty.
- No new keyboard shortcut: the spec-06 §6.6 key map is a MUST list, so adding one requires a spec change first.
- All texts in `app_uk.arb` (primary) + `app_en.arb`, including family names, cost labels, help, failure and
  performance messages.

## 13.7 Performance hint

- While an upscaler is active and playback is running (not paused or buffering), sample mpv
  `vo-delayed-frame-count` and `frame-drop-count` every second. If the delta stays above a threshold for ~10 s, show
  a single hint per session suggesting a lighter preset or Off. **Never switch automatically.**

## 13.8 Delivery stages

Every stage: analyzer clean, tests green, Linux + Android debug builds run.

| Stage | Content | Exit |
|-------|---------|------|
| **U0 — Spike** (throwaway branch) | Hard-coded `glsl-shaders` + `setSize(screen)`. Linux Mesa (Intel/AMD), Linux NVIDIA, Windows ANGLE: record the GL version, which presets compile, and GPU time for 720p→1440p and 1080p→2160p. Try a `media_kit_video` override requesting ES 3 on Windows. | Per-platform support matrix in this spec; decide on the Windows override (else ship Linux first); confirm licenses and asset size. |
| **U1 — Domain + assets** | `upscaling.dart`, `upscaleOutputSize`, `mpv_shaders.dart`, pinned assets + licenses + `LicenseRegistry`, `ShaderStore`. | Unit tests; no UI. |
| **U2 — Backend** | `VideoBackend` additions, `MediaKitVideoBackend` (commands, sizing, failure detection), `FakeVideoBackend`. | Presets run on Linux. |
| **U3 — Controller + prefs** | Key, preferences, controller apply / persist / failure. | Controller tests. |
| **U4 — UI + l10n** | Settings page and row, ARB strings, failure message. | Widget tests; manual Linux + Windows: windowed, fullscreen, floating, PiP. |
| **U5 — Performance hint** | §13.7. | Manual check: heavy preset on a weak iGPU. |
| **U6 — Docs** | README (Linux needs HW GL; Windows notes), acceptance ticked. | — |

## 13.9 Tests (required)

- `upscaleOutputSize`: view ≤ source → null; letterbox/pillarbox fit; devicePixelRatio applied; `maxLongSide` cap.
- `mpvShaderCommands`: `clr` + one `append` per path; a Windows path `C:\…\x.glsl` is passed through unsplit.
- `ShaderStore` (fake bundle, temp dir): extracts; a second call is a no-op; a version bump re-extracts and deletes
  the old dir; a missing `.complete` marker re-extracts.
- Settings: round-trip; unknown id → off.
- Controller (fake backend): the persisted upscaler is applied on backend creation only when supported; a failure →
  off + persisted + message, and the playback error state is untouched.
- Widget: the row is hidden when the list is empty; choosing a preset calls the controller and returns to the root.
- Failure log matcher against log lines recorded in U0.

## 13.10 Risks

- Windows ES 2 context (F4) is the main risk. Fallback: ship Linux first and add Windows after the override (ideally
  upstreamed to media_kit).
- Heavy presets + `framedrop=no` → A/V lag. Mitigated by the cost badges and §13.7.
- Rendering at screen size costs GPU even for light presets. Off keeps the native-size path (no regression).
- mpv log text is not a stable API. Keep the matcher minimal and covered by tests.
