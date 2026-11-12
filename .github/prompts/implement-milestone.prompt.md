---
description: 'Implement one milestone of the Strumok rewrite from the roadmap, end to end, with verification.'
argument-hint: 'Milestone id, e.g. M0, M3'
agent: 'agent'
---

Implement milestone **${input:milestone:M0}** of the Strumok rewrite.

1. Read [roadmap](../instructions/roadmap.instructions.md) and find the milestone scope. Do not start later milestones.
2. For every item, read the referenced spec(s) in `.github/instructions/spec-*.instructions.md` and load matching
   skills from `.github/skills/` (e.g. `rust-supplier-bridge`, `firebase-collection-compat`, `riverpod-feature`,
   `tv-focus-navigation`, `adaptive-video-controls`, `localization-strings`).
3. Break the milestone into small commits (conventional commits). Write tests for domain logic and compatibility first.
4. After implementation run:
   `dart run build_runner build -d && flutter gen-l10n && dart format . && flutter analyze && flutter test`,
   then `flutter build linux --debug` and `flutter build apk --debug`.
5. Check the milestone against the related items of [acceptance](../instructions/acceptance.instructions.md).
6. Report: what was done, verification results, open `// SPEC:` assumptions, anything deferred.
