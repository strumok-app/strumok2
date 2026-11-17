---
description: 'Use when working on settings screens or preference keys.'
applyTo: 'lib/features/settings/**, lib/core/storage/**'
---

# Spec 09 — Settings

Player settings (start position, on-end action, shuffle, subtitle size, equalizer, floating player switch) live only
in the player's settings sheet (spec-06 §6.5.1), not on this page.

Sections (order):

1. **Application version** (mandatory) — current version, latest version, "Check for update", "Update" with
   progress/cancel/error (spec-11 §11.2).
2. **Suppliers bundle** (mandatory) — installed version, latest version (from `FFI_LIB_VERSION_CHECK_URL`),
   check/install/update with progress and error; incompatible major versions are shown but not installable and
   point to the app update (spec-11 §11.1).
3. **Language** — `uk` / `en` (app UI + preferred audio language).
4. **Theme** — brightness (light / system / dark), color scheme picker.
5. **Downloads** — downloads directory picker (desktop only), max parallel downloads, offline mode switch.
6. **Suppliers & recommendations** → sub-page: reorder suppliers (drag on touch/mouse; move up/down buttons on TV),
   enable/disable each supplier, choose recommendation channels per supplier.
7. **Profiles** → manage profiles (spec-05), "ask for profile on startup".

## Preference keys

Use one typed preferences wrapper (provider). The rewrite is a new app (`app.strumok`), so legacy values are not
migrated; reusing the legacy key names below is still recommended for consistency and familiarity in debugging:

```
selected_content_language, selected_content_type, selected_content_suppliers, user_language,
theme_brightness, theme_color_scheme, volume, suppliers_order, suppliers.<name>.enabled,
suppliers.<name>.channels, manga_reader_background, manga_reader_mode, manga_reader_auto_crop,
video_player_setting_shuffle_mode, video_player_setting_ends_action, video_player_setting_start_from,
video_player_setting_fixed_position, video_player_subtitles_size, video_player_equalizer_bands (csv of 5 doubles),
offline_mode, offline_downloads_directory, ffi_supplier_bundle_info (json), floating_video_player_enabled
```

New keys (rewrite): update-check timestamps and "already notified version" for app and supplier bundle (spec-11).

Enum values are stored by `.name`.

All settings screens must be fully operable with the D-pad on TV (switches, radio lists, sliders with ←/→).
