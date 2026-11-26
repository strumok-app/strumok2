---
description: 'Use when working on the manga reader: reading modes, page loading, auto-crop, progress.'
applyTo: 'lib/features/manga/**'
---

# Spec 07 — Manga reader

- Sources: `MangaMediaItemSource` (pages lazily loaded via `load_manga_pages`). Source identity = `description`
  (stored in `currentSourceName`). Translation selector whenever the chapter has sources; display the source's
  language alongside its description when provided, without changing its identity. Its header **Refresh sources**
  reloads the chapter's translations and pages (bypassing the cache), staying on the same translation and page
  (clamped); the error view's Retry does the same.
- Progress: `positions[currentItem] = {position: pageIndex, length: pageCount}`; persist on page change (spec-03).
- Modes (persisted, default `longStrip`): `longStrip` (vertical continuous scroll), `vertical` (paged, vertical),
  `leftToRight` (paged, horizontal), `rightToLeft` (paged, horizontal reversed; new, string already in ARB).
- Background: `dark` (default) / `light`. Auto-crop white/black borders (default on).
- Image loading: send source headers, cache, preload ±2 pages, per-page error with retry, zoom/pan (pinch, double-tap, ctrl+wheel).
- Navigation: tap zones (prev/menu/next), keyboard ←/→/PageUp/PageDown/Space, TV D-pad; next/previous chapter at the ends.
- Overlay controls: chapter title, page slider "N / total", chapter list, settings dialog.
- Offline: pages read from the downloaded `pages_<source>` folder (spec-08).
