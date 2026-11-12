---
name: localization-strings
description: 'Add or change user-visible text in Ukrainian (primary) and English. Use whenever a widget shows text.'
---

# Localization strings

Rules: [localization.instructions.md](../../instructions/localization.instructions.md).

1. Add the key to `lib/l10n/app_uk.arb` (template) with an `@key` description; Ukrainian text first.
2. Add the same key to `lib/l10n/app_en.arb`.
3. Key naming: `<feature><Thing>` camelCase, e.g. `playerSubtitlesOff`, `downloadsDeleteConfirmation`.
   Reuse legacy keys when the meaning is identical.
4. Placeholders/plurals via ICU:
   ```json
   "downloadsEpisodes": "{count, plural, one{{count} епізод} few{{count} епізоди} many{{count} епізодів} other{{count} епізоду}}",
   "@downloadsEpisodes": { "placeholders": { "count": { "type": "int" } } }
   ```
5. Run `flutter gen-l10n`; ensure `untranslated-messages.json` is empty.
6. Use in code: `context.l10n.playerSubtitlesOff` (define `extension on BuildContext` once).
