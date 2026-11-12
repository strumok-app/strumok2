---
description: 'Use when writing tests, fixtures, lint config or commits: testing pyramid, required compatibility fixtures, conventional commits.'
applyTo: 'test/**, integration_test/**, analysis_options.yaml'
---

# Code quality and testing

## Style
- `flutter_lints` (or stricter) with zero analyzer warnings. `dart format` on every change.
- Prefer immutable models (`final` fields, `copyWith`). Enums are serialized by `.name` unless a spec says otherwise.
- Comments only where intent is non-obvious (compat quirks MUST be commented with a link to the spec section).
- No `dynamic` in domain code; JSON boundaries convert to typed models immediately.

## Testing pyramid
| Layer | What to test | Tool |
|-------|--------------|------|
| Domain/pure logic | sync merge rules, id sanitization, JSON round-trips, download scheduler, HLS parsing, TS dejunker (spec-12 §12.6) | `test` |
| Providers | notifiers with fake repositories via `ProviderContainer(overrides: ...)` | `flutter_test` |
| Widgets | adaptive switches (phone/tablet/tv/desktop), focus traversal on TV screens | `flutter_test` |
| Compatibility | fixtures of real legacy Firebase JSON & FRB bundle info; see [acceptance.instructions.md](acceptance.instructions.md) | `test` |
| FFI smoke | load the dummy `content_suppliers_rust` lib and call every API function | integration test (desktop) |

## Required compatibility fixtures (`test/fixtures/`)
- `legacy_collection_item.json` — full item with positions, every status value.
- `legacy_collection_item_positions_array.json` — positions coerced to an array by RTDB.
- `ffi_bundle_info.json` — `{name, version, metadataUrl, downloadUrl{...}}`.

## Commits
- Conventional commits (`feat:`, `fix:`, `refactor:`, `deps:`, `test:`).
- One logical change per commit; generated files (`*.g.dart`) committed together with their sources.
