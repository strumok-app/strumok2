---
description: 'Use when building UI or platform code: DeviceClass (phone/tablet/tv/desktop), breakpoints, input models, Android TV, platform feature matrix, AndroidManifest.'
applyTo: 'lib/app/**, lib/core/platform/**, lib/features/**/presentation/**, android/app/src/main/**'
---

# Platforms and adaptive UI

## Device classes

Compute once at startup and expose via a `keepAlive` provider:

```dart
enum DeviceClass { phone, tablet, tv, desktop }
```

| Class | Detection |
|-------|-----------|
| `tv` | Android and `systemFeatures` contains `android.software.leanback` **or** `android.software.live_tv`; or `--dart-define=FORCE_TV_MODE=true` (dev on desktop). |
| `desktop` | `Platform.isLinux || Platform.isWindows`. |
| `phone` / `tablet` | Android non-TV; `tablet` when `MediaQuery.sizeOf(context).shortestSide >= 600`. |

Layout breakpoint (independent of device class): width `< 450` → bottom navigation; otherwise side navigation rail.

## Input models

| Class | Primary input | Requirements |
|-------|--------------|--------------|
| phone/tablet | touch | Gestures, 48dp targets, system back. |
| tv | D-pad/remote | Every interactive element focusable, visible focus ring, logical focus order, `select`/`enter` activate, `back` closes overlays → pops route. No hover-only UI. No text-input-required flows except search and pairing code. |
| desktop | mouse + keyboard | Hover states, keyboard shortcuts, scroll with mouse wheel/drag, window resizing down to 800×450. |

Global: map `LogicalKeyboardKey.select` → `ActivateIntent` at app root. Allow drag scrolling with mouse, touch and trackpad.

## Platform feature matrix

| Feature | Phone/Tablet | TV | Desktop |
|---------|-------------|----|---------|
| Video controls | Mobile controls | **TV controls** | Desktop controls |
| Floating mini player | ✅ | ❌ | ✅ |
| Picture-in-Picture | ✅ (Android PiP) | ❌ | ✅ (compact always-on-top window) |
| Google sign-in | ✅ native | ❌ → use TV pairing code | ✅ browser consent |
| Generate pairing code (to log in a TV) | ✅ | ❌ | ✅ |
| Enter pairing code | ✅ | ✅ | ✅ |
| Downloads | ✅ (foreground service) | ✅ | ✅ |
| Custom downloads folder | ❌ | ❌ | ✅ |
| Fullscreen toggle | auto-landscape in player | always fullscreen | `F`/double-click |
| Brightness/volume gestures | ✅ | ❌ | ❌ |
| Supplier bundle install/update | ✅ | ✅ | ✅ |
| App self-update | ✅ APK installer | ✅ APK installer | ✅ Windows installer / Linux download link |

## Rules

- Do not scatter `Platform.isX` checks in widgets. Branch on `DeviceClass` (provider) in a small number of
  "adaptive" widgets that pick `*_desktop/*_mobile/*_tv` implementations.
- TV screens must be usable without ever showing a pointer. Test each screen by navigating with arrow keys only (`FORCE_TV_MODE`).
- Respect safe areas and display cutouts on Android; keep the screen awake while playing video.
- Desktop window default 1280×720, centered.
- Android manifest must declare `LEANBACK_LAUNCHER`, `android.software.leanback` (required=false),
  `android.hardware.touchscreen` (required=false), `supportsPictureInPicture=true`, and a TV banner.
