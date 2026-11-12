---
name: rust-supplier-bridge
description: 'Wire, verify or upgrade the flutter_rust_bridge supplier bundle (external Rust content modules). Use when touching content_suppliers_api, content_suppliers_rust, bundle loading/installation, or when an FRB "content hash" / "codegen version" error appears.'
---

# Rust supplier bridge

Contract: [spec-02-content-suppliers-ffi.instructions.md](../../instructions/spec-02-content-suppliers-ffi.instructions.md). FRB codegen `2.12.0`,
content hash `-1122641696`, API major `4`. Reference Rust crate + checksums:
[contract.md](references/contract.md).

## Setting up in a fresh repo
1. Copy `.github/skills/rust-supplier-bridge/assets/content_suppliers_rust/` (Rust crate + `flutter_rust_bridge.yaml`) to
   `packages/content_suppliers_rust/`. Copy the Dart side (`lib/`, `pubspec.yaml`) of `content_suppliers_rust`
   and the whole `content_suppliers_api/` package from the legacy repo into `packages/` **unchanged**.
   Verify the sha256 values listed in [contract.md](./references/contract.md).
2. Reference them as path dependencies from the app `pubspec.yaml`.
3. Expose a `SupplierRegistry` via a keepAlive provider that owns the active `RustContentSuppliersBundle`.
4. Never call `RustLib.init()` (that loads the bundled dummy lib); always use `RustContentSuppliersBundle(directory, libName).load()`.

## Verifying compatibility (run after any change near FFI)
```bash
grep -n "rustContentHash => -1122641696" packages/content_suppliers_rust/lib/rust/frb_generated.dart
grep -n "codegenVersion => '2.12.0'"     packages/content_suppliers_rust/lib/rust/frb_generated.dart
grep -n "compatibleApiVersion = 4"       packages/content_suppliers_rust/lib/bundle.dart
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
- Install exactly `flutter_rust_bridge_codegen 2.12.0`, regenerate, and confirm the hash is still `-1122641696`.
  If the hash changes, **revert** — the published modules will refuse to load.
- Any real API change requires a new major (`5`) coordinated with the suppliers repo; out of scope for the rewrite.

## Common failures
| Symptom | Cause | Fix |
|--------|-------|-----|
| `Content hash on Dart side ... different from Rust side` | bindings regenerated/edited | restore legacy generated files |
| `Rust Suppliers lib not found in path` | wrong dir/name | `lib<name>_<version>.so` / `<name>_<version>.dll` in `<appSupport>/ffi` |
| Loads but suppliers empty | wrong lib (dummy) or old bundle | check `avalaible_suppliers()` and installed bundle info |
| Crash on Android load | wrong ABI download | ABI order x86_64 → arm64-v8a → armeabi-v7a |
