---
description: 'Use when verifying a milestone or release: acceptance checklist for stack, compatibility, pages, player, collection, offline, updates, localization.'
---

# Acceptance checklist

## Stack & platforms
- [ ] Only Flutter + Riverpod + media_kit + flutter_rust_bridge are mandatory deps; every other dep justified (`stack-and-dependencies` instructions).
- [ ] No iOS/macOS/web folders or code paths.
- [ ] Android phone, tablet, Android TV, Linux, Windows builds run.

## Quality
- [ ] `flutter analyze` 0 issues; `flutter test` green; compatibility fixtures present.
- [ ] Every screen fully operable with D-pad in `FORCE_TV_MODE`.
- [ ] No secrets in git.
