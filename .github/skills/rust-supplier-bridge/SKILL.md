---
name: rust-supplier-bridge
description: 'Wire, verify or upgrade the flutter_rust_bridge supplier bundle (external Rust content modules). Use when touching content_suppliers_api, content_suppliers_rust, bundle loading/installation, or when an FRB "content hash" / "codegen version" error appears.'
---

# Rust supplier bridge

Contract: [spec-02-content-suppliers-ffi](../../../docs/specs/spec-02-content-suppliers-ffi.md). FRB codegen `2.13.0`,
content hash `-1122641696`, API major `5`. Reference Rust crate + checksums:
[contract.md](references/contract.md).

## Package layout
The FFI packages live in the app repo and are the source of truth for the contract:
1. `packages/content_suppliers_rust/` — the FRB contract crate (`rust/`, `flutter_rust_bridge.yaml`) plus the
   generated Dart bindings (`lib/rust/`) and the `RustContentSuppliersBundle` adapter (`lib/bundle.dart`).
   Checksums and rules: [contract.md](./references/contract.md).
2. `packages/content_suppliers_api/` — the Dart interfaces. Both are path dependencies of the app `pubspec.yaml`.
3. Expose a `SupplierRegistry` via a keepAlive provider that owns the active `RustContentSuppliersBundle`.
4. Never call `RustLib.init()` (that loads the bundled dummy lib); always use `RustContentSuppliersBundle(directory, libName).load()`.

## Verifying compatibility (run after any change near FFI)
```bash
grep -n "rustContentHash => -1122641696" packages/content_suppliers_rust/lib/rust/frb_generated.dart
grep -n "codegenVersion => '2.13.0'"     packages/content_suppliers_rust/lib/rust/frb_generated.dart
grep -n "compatibleApiVersion = 5"       packages/content_suppliers_rust/lib/bundle.dart
```
All three must match. Then run the FFI smoke test against the dummy lib:
```bash
cd packages/content_suppliers_rust/rust && cargo build --release
flutter test integration_test/ffi_smoke_test.dart -d linux \
  --dart-define=FFI_SUPPLIER_LIB_NAME=content_suppliers_rust \
  --dart-define=FFI_SUPPLIER_LIBS_DIR=packages/content_suppliers_rust/rust/target/release
```
The smoke test must call every API function on supplier `"dummy"` (channels, default channels, types, languages,
search, load_channel, details incl. `eager_sources` id, load_media_items, load_media_item_sources, load_manga_pages).
Note: the dummy crate's hash differs from the real bundle only if its API differs — it must not.

## If regeneration is ever unavoidable
- Install exactly `flutter_rust_bridge_codegen 2.13.0`, regenerate (`flutter_rust_bridge_codegen generate` from
  `packages/content_suppliers_rust/`), and confirm the hash is still `-1122641696` (it is derived from the codegen
  config, so an unchanged `flutter_rust_bridge.yaml` keeps it stable even across model edits). If it changes, the
  config drifted — restore it.
- A real `api`/`models` change (e.g. the API-5 `language` field on `ContentMediaItemSource`) requires bumping the
  bundle major and `compatibleApiVersion` together, regenerating the Dart bindings, and coordinating with the
  `strumok_suppliers` repo so published modules advertise the new major.

## Common failures
| Symptom | Cause | Fix |
|--------|-------|-----|
| `Content hash on Dart side ... different from Rust side` | bindings regenerated/edited | restore legacy generated files |
| `Rust Suppliers lib not found in path` | wrong dir/name | `lib<name>_<version>.so` / `<name>_<version>.dll` in `<appSupport>/ffi` |
| Loads but suppliers empty | wrong lib (dummy) or old bundle | check `avalaible_suppliers()` and installed bundle info |
| Crash on Android load | wrong ABI download | ABI order x86_64 → arm64-v8a → armeabi-v7a |
