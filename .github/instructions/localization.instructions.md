---
description: 'Use when adding or changing user-visible text, ARB files, gen-l10n, Ukrainian/English localization, plurals.'
applyTo: 'lib/l10n/**, l10n.yaml, lib/features/**/presentation/**'
---

# Localization

- Languages: **Ukrainian (`uk`) — primary/default**, English (`en`) — secondary. No other locales.
- Use Flutter `gen-l10n` with ARB files in `lib/l10n/`:
  - `l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file: app_uk.arb`, `output-localization-file: app_localizations.dart`,
    `untranslated-messages-file: untranslated-messages.json`.
  - Template is **`app_uk.arb`** (primary). `app_en.arb` must contain every key.
- Seed both ARB files from the legacy repo (`lib/l10n/app_uk.arb`, `lib/l10n/app_en.arb`) and keep existing key
  names where the meaning is unchanged. Drop keys only for removed features (AI search, etc.).
- Default app locale: user setting if set, otherwise `uk` (even if the OS is in another language — fall back to `uk`, not `en`).
- The user-language setting is also used as preferred audio/video track language for the player (`alang/vlang = <user>,en`).
- No string concatenation for sentences; use ICU placeholders/plurals (`{count, plural, ...}`).
- Ukrainian plurals need `one/few/many/other`.
- Content metadata from suppliers (titles, descriptions) is **not** translated.
- `untranslated-messages.json` must be empty before a milestone is complete.
