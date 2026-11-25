---
description: 'Use when working on video upscaling: mpv GLSL shaders (RAVU, Anime4K, FSRCNNX, NNEDI3), VideoBackend upscaler API, render output sizing, shader assets/extraction, upscaling settings page.'
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
| F4 | Both desktop embedders request a **GLES 2** context (`EGL_CONTEXT_CLIENT_VERSION 2`). Linux uses EGL; Windows uses ANGLE on D3D11. | `linux/video_output.cc`, `windows/angle_surface_manager.h` | Mesa and NVIDIA usually return a newer ES 3.x context (U0: Linux/Intel Mesa → **GLES 3.2** confirmed). ANGLE likely returns exactly ES 2.0, and most prescalers fail there. Windows may need a `media_kit_video` override that requests ES 3 (verified in U0). Compute shaders need GL 4.3 / ES 3.1: **fragment variants only**. |
| F7 | On every `videoParams` change (new file, quality switch, rotation), media_kit calls `VideoOutputManager.SetSize` with the video size and so **overrides a fixed size**. `NativeVideoController.setSize` also returns early when the requested size equals its cached `width/height`, even after such a reset. | `native_video_controller/real.dart` (`videoParamsSubscription`, `setSize`) | After each `videoParams` event the backend MUST re-apply the output size (debounced), going through `setSize()` (native) and then `setSize(w, h)` so the dedupe check doesn't skip it. |
| F5 | The player runs `framedrop=no` + `video-sync=audio` (spec-06 §6.3). | `media_kit_backend.dart` | U0: with an over-budget shader the video falls behind audio and **never recovers** (frozen until the player closes), even after switching to a light preset or Off. With `framedrop=vo` it catches up. So **while any upscaler is active (every preset, regardless of cost or GPU) the backend MUST set `framedrop=vo`**, and restore `no` when upscaling is off (the only exception to §6.3). |
| F8 | Through the libmpv render API, `vo-passes` is empty and `vo-delayed-frame-count` stays 0. `avsync` and `frame-drop-count` work. | U0 spike log | No in-app GPU timing. Overload detection (§13.7) uses `frame-drop-count` (VO drops with `framedrop=vo`) and `avsync`. |
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

> **Shipped catalog (post-U0 field testing):** Anime4K **`anime4k_a_fast`** and the HQ modes **`anime4k_a_hq`**,
> **`anime4k_b_hq`**, **`anime4k_c_hq`**, plus an experimental **`custom_detail_cas_grain`** chain (SSimSuperRes luma
> detail → AMD CAS sharpening → film grain). FSRCNNX, RAVU and NNEDI3 made no noticeable difference in real-world use
> and were removed (catalog entries, shader assets, `UpscalerFamily` values and l10n all dropped). The table below is
> the original evaluated catalog.
>
> **Shader license bundling was removed** (no `LICENSE`/`GPL-3.0.txt` assets, no `shaderLicenses`, no
> `registerShaderLicenses`/`LicenseRegistry`), overriding the "register with LicenseRegistry" MUST in this section.

Fragment-shader variants only (see F4). Files live in `assets/shaders/<family>/`, shipped **unmodified**. Each one
is pinned to an
upstream release or commit, with its license and sha256, in `assets/shaders/README.md`. The ids are stable,
persisted values. If a preset is removed later, its id must still resolve to "off".

| id | Family | Files | Cost | Anime hint |
|----|--------|-------|------|------------|
| `fsrcnnx_8` | FSRCNNX | `FSRCNNX_x2_8-0-4-1.glsl` | light | — |
| `fsrcnnx_16` | FSRCNNX | `FSRCNNX_x2_16-0-4-1.glsl` | heavy | — |
| `ravu_lite_r4` | RAVU | `ravu-lite-ar-r4.hook` | light | — |
| `ravu_zoom_r3` | RAVU | `ravu-zoom-ar-r3.hook` (5.2 MB, embedded LUT) | light | — |
| `nnedi3_64` | NNEDI3 | `nnedi3-nns64-win8x6.hook` | medium | — |
| `nnedi3_128` | NNEDI3 | `nnedi3-nns128-win8x6.hook` | heavy | — |
| `anime4k_a_fast` | Anime4K v4 | `Anime4K_Clamp_Highlights`, `Restore_CNN_M`, `Upscale_CNN_x2_M`, `AutoDownscalePre_x2`, `AutoDownscalePre_x4`, `Upscale_CNN_x2_S` | light | yes |
| `anime4k_a_hq` | Anime4K v4 | official mode A (HQ) chain (`_VL`/`_L` variants) | heavy | yes |
| `anime4k_b_hq` | Anime4K v4 | official mode B (HQ) chain | heavy | yes |
| `anime4k_c_hq` | Anime4K v4 | official mode C (HQ) chain | medium | yes |

- Cost = GPU time per frame on a reference iGPU (Intel Arrow Lake, GLES, 720p → 1080p; U0): light < 20 ms,
  medium 20–40 ms, heavy > 41.7 ms (more than one 24 fps frame, so it only plays with dropped frames).
- Presets that fail on a platform in U0 MUST be excluded from that platform's `supportedUpscalers`.
- **Dropped after U0:** ArtCNN v1.6.x. Its compute shaders need fp16 arithmetic
  (`GL_EXT_shader_explicit_arithmetic_types_float16`), which in practice is Vulkan-only. On OpenGL/GLES, mpv's `gpu`
  renderer **aborts** (`video.c: copy_image` assertion), which **crashed the app**, and `gpu-next` skips the shader.
  media_kit renders through the libmpv OpenGL render API, so neither Vulkan nor `gpu-next` is available. A native crash can't be caught from Dart, so **only presets verified
  on a platform may be offered there**. Failure detection (§13.4) is a fallback for driver differences, not a
  safety net.
- **Licenses (verified):** Anime4K is MIT. FSRCNNX, RAVU and NNEDI3 files are LGPL-3.0-or-later (per
  file headers; the FSRCNN-TensorFlow *repo* is GPL-3.0, but the released shaders are LGPL). Each family folder holds
  its `LICENSE`; `assets/shaders/GPL-3.0.txt` ships the GPL text that LGPL-3.0 builds on. Register all of them
  with `LicenseRegistry`.
- `.hook` (mpv-prescalers) is upstream's extension. mpv loads it like `.glsl`. Keep the upstream names.
- Anime4K chains match upstream's mpv templates (`md/Template/GLSL_Mac_Linux_{High,Low}-end/input.conf`), listed
  in `assets/shaders/README.md`.
- Total ≈ 6.8 MB, of which `ravu-zoom-ar-r3` is 5.2 MB (the r2 variant would be 3.0 MB). The catalog is kept
  as-is until U0 testing, then trimmed to what works and performs well.
- **Desktop-only bundling (MUST):** register every shader folder with a platform filter (Flutter
  `platforms:` asset key, supported by the pinned SDK 3.47.9; folder entries are not recursive), so Android builds don't include the shaders:
  ```yaml
  flutter:
    assets:
      - path: assets/shaders/anime4k/
        platforms: [linux, windows]
      # … the same for fsrcnnx/, ravu/, nnedi3/ and assets/shaders/GPL-3.0.txt
  ```
  Register the licenses with `LicenseRegistry` only on desktop. Android builds must not reference the missing
  assets.

## 13.4 Architecture

### Domain (pure) — `lib/features/player/domain/upscaling.dart`
```dart
enum UpscalerFamily { fsrcnnx, ravu, nnedi3, anime4k }
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
  `rootBundle` into `<AppPaths.support>/shaders/v<shaderCatalogVersion>/<family>/<file>`. Each file is written under a
  temporary name and renamed, so an existing file is always complete. Files shared between chains are extracted
  once. Other catalog versions and leftover temp files are deleted on first use. The same code path is used on every
  platform. **Bump `shaderCatalogVersion` whenever a shader file changes.**
- `MediaKitVideoBackend`:
  - `supportedUpscalers`: the catalog filtered by platform (Linux; Windows only after T9 passes, see U0 results),
    minus presets excluded for the platform (§13.3). Decided in `videoBackendFactory`. media_kit doesn't report
    whether it fell back to SW rendering, so that isn't checked. mpv ignores user shaders there, so a selected
    upscaler has no effect but does no harm.
  - `setUpscaler`: `await _configured` → extract → run `mpvShaderCommands` → `framedrop=vo` (F5) → enable output
    sizing. Off runs `clr`, restores `framedrop=no` and the native size (`setSize()` with nulls).
  - **Output sizing (F3):** `buildView()` wraps `Video` in a `LayoutBuilder` and uses `MediaQuery.devicePixelRatioOf`.
    While an upscaler is active, it calls `VideoController.setSize` with `upscaleOutputSize(...)`, debounced
    ~150 ms for window resize and fullscreen changes, and re-evaluates when the video size or aspect changes.
    When the result is null (floating player, PiP, view ≤ source), it restores the native size.
  - **Failure detection:** listen to `Player.stream.log` (`PlayerConfiguration.logLevel` ≥ warn). Error lines from
    the `vo`/`libmpv` prefixes about shader compile/link failures or unsupported features → `clr` shaders, restore
    native size, emit `upscalerFailures` (`isShaderFailureLog` in `mpv_shaders.dart`, error level only, so mpv keeps
    the default `logLevel`). Keep the matcher small and test it with log lines recorded in U0. A failure while
    extracting or applying also counts as an upscaler failure.
  - `dispose` cancels the log subscription and the sizing debounce.

## 13.5 Settings and controller

- Preference key `video_player_upscaler` (string id; absent = off), constant `AppPreferences.videoPlayerUpscaler`
  (spec-09). Local only; never synced to Firebase (the collection contract is unchanged).
- `PlayerPreferences.upscaler` (`String?`) + `PlayerSettings.setUpscaler`.
- `PlayerController`:
  - `setUpscaler(Upscaler?)`: persist, then apply to the backend.
  - In `_createBackend()`: apply the persisted upscaler (next to the audio effects), only if it is in
    `supportedUpscalers`.
  - On `upscalerFailures`: persist off and re-emit on `PlayerController.upscalerFailures`; the UI shows a localized
    message once (U4). Playback continues.
  - The stored id is kept on devices that can't run it (it may be supported elsewhere); `PlayerController.upscaler`
    resolves it to null there.
  - Expose `supportedUpscalers` for the UI.

## 13.6 UI

- Player settings side sheet (spec-06 §6.5.1): row **Upscaling right after Quality** (`settings-upscaling`). The
  root shows "Off" or `<family> · <variant>` (`upscalerLabel`). Hidden when `supportedUpscalers` is empty.
- Page: "Off", then the **supported** presets grouped by family under non-focusable family headers. Each preset
  shows its variant name, with the cost (Light / Medium / Heavy) and "For anime" (where `forAnime`) as subtitle. A
  non-focusable help line at the end says it uses the GPU and heavy modes skip frames on a weak one. Choosing a
  value applies it, persists it and returns to the root (existing pattern).
- Failure message: `PlayerPage` listens to `PlayerController.upscalerFailures` and shows a snackbar
  ("Couldn't turn on “<name>”. Upscaling is off."). In the floating player there's no message; the setting still
  turns off.
- No new keyboard shortcut: the spec-06 §6.6 key map is a MUST list, so adding one requires a spec change first.
- Texts live in `app_uk.arb` (primary) + `app_en.arb` (`playerUpscaling*`, `playerUpscaler*`). Family names are proper
  nouns, identical in both languages.

## 13.7 Performance hint

- While an upscaler is active and playback is running (not paused or buffering), sample mpv `frame-drop-count`
  (VO drops, F5) and `avsync` every second (F8). If the drop rate stays above ~10 % of the video fps for ~10 s,
  show a single hint per session suggesting a lighter preset or Off. **Never switch automatically.**
- `avsync` jitters by up to ~5 frames (~170 ms at 30 fps) even when healthy. Never use one sample as a signal.

## 13.8 Benchmark

Setup: 720p source → 1080p output in fullscreen, spike branch `spike/upscaling-u0`, plus an mpv CLI benchmark with
the same settings (`vo=gpu`, GLES, `framedrop=no`, `video-sync=audio`). GPU ms = CLI `vo-passes` per frame.
The 24 fps budget is 41.7 ms per frame.

| Preset | Intel Arrow Lake (Mesa, GLES 3.2): GPU ms | Intel in app | NVIDIA RTX PRO 3000 (GLES 3.2): GPU ms | NVIDIA in app | Windows |
|--------|------|------|------|------|------|
| `ravu_zoom_r3` | 11.2 | ✅ | 1.0 | ✅ | not tested |
| `ravu_lite_r4` | 12.3 | ✅ | 0.8 | ✅ | not tested |
| `fsrcnnx_8` | 17.1 | ✅ | 3.9 | ✅ | not tested |
| `anime4k_a_fast` | 17.9 | ✅ | 6.5 | ✅ | not tested |
| `nnedi3_64` | timer 0 | lag grows → OK with `framedrop=vo` | 7.7 | ✅ | not tested |
| `anime4k_c_hq` | 36.5 | lag grows → OK with `framedrop=vo` | 10.4 | ✅ (colour artifacts, see below) | not tested |
| `fsrcnnx_16` | 55.6 | lag grows → OK with `framedrop=vo` | 10.2 | ✅ | not tested |
| `anime4k_a_hq` | 65.5 | lag grows → OK with `framedrop=vo` | 21.3 | ✅ (colour artifacts) | not tested |
| `anime4k_b_hq` | — | lag grows → OK with `framedrop=vo` | — | ✅ (colour artifacts) | not tested |
| `nnedi3_128` | 71.2 | lag grows → OK with `framedrop=vo` | 20.0 | lag 1.4 s with `framedrop=no` | not tested |
| ArtCNN | — | ❌ mpv abort → app crash | — | — | dropped |

Also verified on Linux: output sizing for fullscreen/windowed/resize (T4); episode, quality and source changes keep
the upscaled size (T5, F7); floating player and PiP go native and come back upscaled (T6); `hlsProxy` and
downloaded files (T7).

Decisions:
- `framedrop=vo` while an upscaler is active (F5). With it, every remaining preset is playable on both GPUs; heavy
  ones drop frames on weak GPUs, which is what the cost badge and the §13.7 hint are for.
- The catalog stays as listed in §13.3; cost labels are taken from the Intel numbers.
- NVIDIA colour artifacts with the Anime4K HQ chains are a known issue that won't be investigated. The mpv CLI on
  the same GPU picks `rgba16f` FBOs, so the cause is not the FBO format.
- **Windows is still unverified** (ANGLE GL version, compile results). U1–U4 build the Windows path the same way
  as Linux, but `supportedUpscalers` stays **empty on Windows** until a Windows run of the U0 test plan (T9)
  passes.

## 13.9 Tests (required)

- `upscaleOutputSize`: view ≤ source → null; letterbox/pillarbox fit; devicePixelRatio applied; `maxLongSide` cap.
- `mpvShaderCommands`: `clr` + one `append` per path; a Windows path `C:\…\x.glsl` is passed through unsplit.
- `ShaderStore` (fake bundle, temp dir): extracts in hook order; a second call loads nothing; shared files load once;
  a version bump deletes the old dir and leftover temp files.
- Catalog: every upscaler maps to shader files that exist in `assets/shaders/`.
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
