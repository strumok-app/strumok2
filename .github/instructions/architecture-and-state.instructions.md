---
description: 'Use when writing Dart code in lib/: feature folder layout, Riverpod providers/notifiers, layering, networking, error handling.'
applyTo: 'lib/**/*.dart'
---

# Architecture and state management

## Project layout (feature-first)

```text
lib/
├── main.dart                 # bootstrap only: init services, runApp(ProviderScope(...))
├── app/                      # MaterialApp, router, theme, shell layouts
├── core/                     # cross-cutting: platform detection, http client, logging, result types
│   ├── platform/             # DeviceClass, TV detection, window helpers
│   ├── storage/              # prefs + local DB wrappers
│   ├── hls/                  # HLS parser, TS dejunker, AES-128 decryptor, local dejunking proxy (spec-12)
│   └── l10n/                 # generated localizations (output of gen-l10n)
├── features/
│   ├── suppliers/            # FRB bundle loading, supplier registry, bundle updates
│   ├── home/                 # recommendations
│   ├── search/
│   ├── collection/           # local repo, firebase sync, collection UI
│   ├── profiles/             # multi-tenant profiles (spec-05)
│   ├── auth/                 # google sign-in, TV pairing
│   ├── details/
│   ├── player/               # controller, backend (media_kit), controls/{desktop,mobile,tv}, pip, floating
│   ├── manga/
│   ├── downloads/            # download manager, offline storage
│   ├── updates/              # app self-update + supplier bundle update checks (spec-11)
│   └── settings/
packages/
├── content_suppliers_api/    # copied verbatim from legacy repo
└── content_suppliers_rust/   # copied verbatim from legacy repo (FRB bindings)
```

Each feature folder: `data/` (repositories, DTOs, platform code), `domain/` (pure models & logic,
no Flutter imports where possible), `presentation/` (widgets + providers). Keep files < ~400 lines;
split widgets by device class (`*_desktop.dart`, `*_mobile.dart`, `*_tv.dart`) when layouts differ.

## Riverpod conventions

- Use code generation: `@riverpod` / `@Riverpod(keepAlive: true)`; run `dart run build_runner build -d`.
- **No global singletons for mutable state.** Services (supplier registry, download manager, offline storage,
  HTTP client, DB) are exposed via `keepAlive` providers. Tests override them with `ProviderScope(overrides: ...)`.
- Infrastructure that must exist before `runApp` (prefs, DB, Firebase init, FRB bundle) is initialized in
  `main()` and injected via `overrideWithValue` on the root `ProviderScope`.
- Async state: `AsyncNotifier`/`FutureProvider`; render with `switch (asyncValue) { AsyncData() ... }`.
- Mutations live in `Notifier` methods; widgets never call repositories directly.
- Use `ref.watch` in `build`, `ref.read` in callbacks, `ref.listen` for side effects (navigation, snackbars).
- Family providers for per-content state (e.g. `collectionItemProvider((supplier, id))`). Use records or
  `Equatable` keys — **never** pass a non-equatable object as a family argument.
- Check `ref.mounted` after every `await` in notifiers before assigning `state`.
- Disable automatic retry on the root scope (`retry: (_, __) => null`) — supplier calls are not idempotent-cheap.
- High-frequency values (playback position, download progress) must not rebuild large trees:
  expose them as `Stream`/`ValueListenable` or `select` narrowly.

## Layer rules

- `domain/` never imports `firebase_*`, `media_kit`, `flutter_rust_bridge` or platform channels.
- Supplier access goes only through the `ContentSupplier` interface from `content_suppliers_api`.
- Collection access goes only through a `CollectionRepository` interface (local and synced implementations).
- Platform-specific code (Android MethodChannels, window manager) lives behind an interface in `core/platform`
  with one implementation per platform and a no-op fallback.

## Networking

- One shared HTTP client provider (`httpClientProvider`) used by app code (supplier libs do their own networking in Rust).
  It is an `AlpnHttpClient` (pure Dart, `http2` package, HTTP/1.1 fallback) created in `main()` and must support HTTP/2; every app HTTP operation goes through it.
- Always forward supplier-provided `headers` when fetching media, subtitles, manga pages or downloads.
- Timeouts: 30 s default. Never retry on 4xx.

## Errors and logging

- Wrap supplier/FFI errors in `ContentSuppliersException` with supplier name + id + operation.
- Every screen that loads data has loading, empty, and error states with a **Retry** action (focusable on TV).
- Use `package:logging`; no `print` outside the root log listener.
