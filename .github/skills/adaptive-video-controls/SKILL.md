---
name: adaptive-video-controls
description: 'Build or modify video player controls, floating player, or PiP across desktop, phone/tablet and Android TV. Use for any work in lib/features/player.'
---

# Adaptive video controls

Spec: [spec-06-video-player.instructions.md](../../instructions/spec-06-video-player.instructions.md).

## Structure
```
features/player/
  domain/   player_state.dart, playlist.dart, progress_policy.dart (pure, tested)
  data/     media_kit_backend.dart, subtitles/ (vtt+srt parser), pip/{pip.dart,pip_android.dart,pip_desktop.dart,pip_unsupported.dart}
            (HLS proxy + dejunker live in lib/core/hls/, spec-12)
  presentation/
    player_controller.dart            # Riverpod notifier, owns backend
    player_screen.dart                # picks controls by DeviceClass
    controls/desktop/…  controls/mobile/…  controls/tv/…
    shared/ seek_bar.dart, source_selector.dart, subtitle_selector.dart, tracks_selector.dart, equalizer.dart, player_settings.dart
    floating_player_overlay.dart
```

## Rules
- Controls read state via narrow `select`/streams; position ticks must not rebuild the whole screen.
- Shared building blocks (seek bar, selectors) are reused, but each device class composes its own layout & input.
- Controls never talk to media_kit directly — only through the controller.
- The video surface widget is created once per backend and moved between full-screen / floating / PiP hosts
  (avoid recreating `VideoController`).
- Never start playback twice for the same (item, source) — guard with request tokens.
- Desktop keyboard map, TV D-pad behavior and mobile gestures are specified in spec §6.6–6.8 — implement exactly.
- On TV: no floating player, no PiP.
- Save progress via the collection notifier per spec-03 §3.3 (debounced), and once more on pause/exit/item change.

## Verification
- Desktop: every hotkey in §6.6; fullscreen enter/exit; PiP window enter/exit restores bounds.
- Android phone: gestures, lock, rotation, PiP via home button and via button, PiP remote actions.
- TV (`FORCE_TV_MODE` + real device/emulator): full playback session with remote only.
- Source with `hlsProxy=true` (junked TS segments) plays through the proxy; seeking works; switching sources keeps position.
