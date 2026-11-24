---
description: 'Use when working with content suppliers, flutter_rust_bridge, Rust FFI bundle loading, supplier API semantics (params, headers, hlsProxy), bundle info JSON. Compatibility contract.'
applyTo: 'lib/features/suppliers/**, packages/content_suppliers_api/**, packages/content_suppliers_rust/**'
---

# Spec 02 — Content suppliers via flutter_rust_bridge (COMPATIBILITY CONTRACT)

External content modules are prebuilt Rust dynamic libraries (`strumok_suppliers`, separate repo,
currently `5.x`). The app downloads them at runtime and loads them through FRB. The rewrite **MUST** load
the published libraries of the compatible major without any change on the Rust side.

## 2.1 Binary contract — MUST

| Item | Value |
|------|-------|
| FRB codegen version (Rust side) | `2.13.0` (`flutter_rust_bridge = "=2.13.0"`) |
| FRB content hash | **`-1122641696`** (Dart `rustContentHash` must equal Rust `FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH`; derived from the codegen config, so unchanged by API-5 field additions) |
| Compatible API major version | **`5`** (`compatibleApiVersion = 5`; bundle `version.major` must equal it) |
| `forceSameCodegenVersion` | `false` (Dart runtime may be newer, e.g. 2.13.x) |
| Rust input module | `crate::api` |

FRB calls functions by **numeric `funcId`** and validates the content hash, so the Dart bindings must be
generated from the same Rust API signatures as the published bundle. Because the content hash is config-derived
rather than API-derived, the `compatibleApiVersion` gate (not the hash) is what rejects bundles of an older major.
**Do not casually regenerate or edit** the bindings; a deliberate contract change is a coordinated bundle-major bump
(as done for API 5) with a matching `compatibleApiVersion`.

**The FRB contract crate lives in the repo:** [content_suppliers_rust/](../../packages/content_suppliers_rust/)
(`rust/src/api/mod.rs`, `rust/src/models.rs`, `rust/src/frb_generated.rs`, `rust/src/suppliers/` with the `dummy`
test supplier, `rust/Cargo.toml`/`Cargo.lock`, `flutter_rust_bridge.yaml`). Checksums and rules:
[contract.md](../../.github/skills/rust-supplier-bridge/references/contract.md).

The Dart side lives alongside it:

- `content_suppliers_api/` — Dart interfaces (`ContentSupplier`, `ContentInfo`, `ContentDetails`,
  `ContentMediaItem`, `ContentMediaItemSource`, `VideoMediaItemSource`, `FileMediaItemSource`,
  `MangaMediaItemSource`, `SegmentedList`, `ContentSupplierBundle`, `ContentSuppliersException`).
- `content_suppliers_rust/` — generated `lib/rust/*`, and the
  `RustContentSuppliersBundle` adapter in `lib/bundle.dart` (custom `BaseEntrypoint` that loads a library
  by path); its `rust/` folder is the contract crate above.

If you must touch these packages, use the `rust-supplier-bridge` skill and prove the hash is unchanged.

## 2.2 Rust API surface (summary; authoritative source: [mod.rs](../../packages/content_suppliers_rust/rust/src/api/mod.rs) and [models.rs](../../packages/content_suppliers_rust/rust/src/models.rs))

```rust
#[frb(sync)] fn get_channels(supplier: String) -> Result<Vec<String>>;
#[frb(sync)] fn get_default_channels(supplier: String) -> Result<Vec<String>>;
#[frb(sync)] fn get_supported_types(supplier: String) -> Result<Vec<ContentType>>;
#[frb(sync)] fn get_supported_languages(supplier: String) -> Result<Vec<String>>; // "en" | "uk" | "ja"
async fn search(supplier: String, query: String, page: u16) -> Result<Vec<ContentInfo>>;
async fn load_channel(supplier: String, channel: String, page: u16) -> Result<Vec<ContentInfo>>;
async fn get_content_details(supplier: String, id: String) -> Result<Option<ContentDetails>>;
async fn load_media_items(supplier: String, id: String, params: Vec<String>) -> Result<Vec<ContentMediaItem>>;
async fn load_media_item_sources(supplier: String, id: String, params: Vec<String>) -> Result<Vec<ContentMediaItemSource>>;
async fn load_manga_pages(supplier: String, id: String, params: Vec<String>) -> Result<Vec<String>>;
#[frb(sync)] fn avalaible_suppliers() -> Vec<String>; // sic: misspelling is part of the ABI
#[frb(init)] fn init_app();
```

Models:

```rust
enum ContentType { Movie, Anime, Cartoon, Series, Manga }
enum MediaType { Video, Manga }
struct ContentInfo { id, title, secondary_title: Option<String>, image }
struct ContentDetails { title, original_title: Option<String>, image, description, media_type: MediaType,
  additional_info: Vec<String>, similar: Vec<ContentInfo>, media_items: Option<Vec<ContentMediaItem>>, params: Vec<String> }
struct ContentMediaItem { title, section: Option<String>, image: Option<String>,
  sources: Option<Vec<ContentMediaItemSource>>, params: Vec<String> }
enum ContentMediaItemSource {
  Video { link, description, headers: Option<HashMap<String,String>>, hls_proxy: bool, language: Option<String> },
  Subtitle { link, description, headers: Option<HashMap<String,String>>, language: Option<String> },
  Manga { description, headers: Option<HashMap<String,String>>, pages: Option<Vec<String>>, params: Vec<String>, language: Option<String> },
}
```

## 2.3 Semantics the app MUST honor

- **Lazy loading via `params`**: if `ContentDetails.media_items` is `None`, call `load_media_items(id, details.params)`.
  If `ContentMediaItem.sources` is `None`, call `load_media_item_sources(id, item.params)`.
  If `Manga.pages` is `None`, call `load_manga_pages(id, source.params)`. Cache results per object.
- Media item **position = index** in the returned list (0-based). This index is what the collection stores as
  `currentItem` and as `positions` keys — never re-sort items.
- Enum mapping Rust→Dart is by lowercase name (`Movie`→`movie`). Unknown values are ignored, not errors.
- Supported languages are strings matched to `ContentLanguage.name` (`en`, `uk`); other codes (e.g. legacy `ja`) are ignored.
- Each `ContentMediaItemSource` carries an optional `language` (API 5): a supplier-reported code mapped to
  `ContentLanguage?` the same way as supported languages (unknown/absent codes become `null`).
- `headers` MUST be sent for every request to that source (player, downloads, subtitles, manga images).
- `hls_proxy: true` means the source's HLS segments are disguised with a junk prefix: playback MUST go through the
  local dejunking HLS proxy ([spec-12](spec-12-hls-ts-dejunking.md)). Downloads dejunk TS segments always,
  so the flag does not change download behavior.
- Video source identity is its `description` (stored as `currentSourceName`); subtitles likewise (`currentSubtitleName`).
- Search & channel pages are **1-based** in app usage.
- Wrap every FFI error into `ContentSuppliersException("FFI <Op> Failed [supplier=.. id=..] error: ..")`.

## 2.4 Bundle distribution and installation — MUST

Bundle metadata JSON (fetched from `FFI_LIB_VERSION_CHECK_URL`, persisted in prefs key `ffi_supplier_bundle_info`):

```json
{
  "name": "strumok_suppliers",
  "version": "4.3.0",
  "metadataUrl": "https://...",
  "downloadUrl": {
    "linux": "https://.../libstrumok_suppliers_4.3.0.so",
    "windows": "https://.../strumok_suppliers_4.3.0.dll",
    "arm64-v8a": "https://...",
    "armeabi-v7a": "https://...",
    "android-x86_64": "https://..."
  }
}
```

- `version` is a semver string (optional leading `v`).
- `libName = "${name}_${version}"`; file name: Windows `"$libName.dll"`, Linux/Android `"lib$libName.so"`.
- Install dir: `<applicationSupportDirectory>/ffi/`.
- Android ABI selection order: `x86_64` → `android-x86_64`, then `arm64-v8a`, then `armeabi-v7a`.
- Install flow: check `version.major == 5` → download to install dir → load bundle (`RustContentSuppliersBundle(directory, libName).load()`) →
  if load succeeds, swap the active bundle, persist info, refresh supplier-dependent providers, delete older files of the same `name`.
- Startup: if prefs contain info, file exists, and major is compatible → load. Otherwise show the install prompt.
- Developer override: `--dart-define=FFI_SUPPLIER_LIB_NAME=<stem>` and `FFI_SUPPLIER_LIBS_DIR=<dir relative to cwd>`.
- Unload (`DynamicLibrary.close`) the previous bundle only after the new one loaded successfully.
- Install/update user flows (startup guard, update checks, hot swap) are **mandatory** and specified in
  [spec-11-app-and-suppliers-updates](spec-11-app-and-suppliers-updates.md).

## 2.5 Supplier configuration (per supplier, persisted)

- Enabled flag (default: enabled if `supportedLanguages` contains the current app UI language, e.g. `uk`).
- Selected recommendation channels (default: `get_default_channels`; saved set is intersected with current `get_channels`).
- Global user-defined supplier order (new suppliers appended; missing ones removed).
