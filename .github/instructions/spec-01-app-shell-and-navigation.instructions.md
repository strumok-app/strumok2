---
description: 'Use when working on app shell, routing, navigation layouts, Home, Search, Collection/Library or Details pages, theming.'
applyTo: 'lib/app/**, lib/features/home/**, lib/features/search/**, lib/features/details/**, lib/features/collection/presentation/**'
---

# Spec 01 — App shell and navigation

## Pages (same general layout as the legacy app)

| # | Page | Route | In main nav | Notes |
|---|------|-------|-------------|-------|
| 1 | **Home** | `/` (initial) | ✅ icon `home` | Recommendations + "continue watching" row. |
| 2 | **Search** | `/search` | ✅ icon `search` | |
| 3 | **Collection / Library** | `/collection` | ✅ icon `favorite` | |
| 4 | **Details** | `/content/:supplier/:id` | – | Video or manga details. |
| 5a | **Video player** | `/video/:supplier/:id` | – | Full-screen player. |
| 5b | **Manga reader** | `/manga/:supplier/:id` | – | |
| 6 | **Settings** | `/settings` | via account menu / side rail bottom | Sub-route `/settings/suppliers`. |
| – | Downloads (offline items) | `/downloads` | via account menu | See spec-08. |

Main navigation order: Home, Search, Collection. Settings, Downloads, Profile/Account are reached from the
account menu (avatar button) shown as the last bottom-bar item (bottom-nav layout) or at the bottom of the side rail.

## Shell layouts

- Width `< 450` → **bottom navigation** layout: compact, no top bar; 50 dp bar with icon-only destinations
  plus the account avatar; back is the system back (Android) / Escape (desktop), no on-screen back button.
- Width `≥ 450` → **side navigation rail** layout; show a back button on non-root pages except on TV
  (TV uses the remote's back key).
- The shell wraps every page except the player and manga reader (they are full-screen).
- A **floating video player overlay** sits above the router in a `Stack` at the app root (spec-06).
- A **startup guard** wraps the app: if no supplier bundle is installed/compatible, show the install
  prompt (spec-11 §11.1) instead of empty pages.
- Update notices (app and supplier bundle, spec-11) appear as a badge on the account/settings entry.

## Home
- Row "Continue": collection items with status `inProgress`; if none, status `latter` (watch later). Sorted by priority desc, lastSeen desc.
- For each enabled supplier (user-defined order) and each enabled channel: horizontal list from
  `loadChannel(channel, page)`; pages are **1-based**; "load more" at the end of the row (lazy for touch/mouse, explicit focusable tile on TV).
- Empty state hint: "configure recommendations in settings".
- In offline mode Home shows downloaded content instead (spec-08).

## Search
- Text field with suggestions from local search history (store last queries; prune entries older than ~30 days).
- Filters: content language (`en`, `uk`, `ja`), content type (`movie`, `anime`, `cartoon`, `series`, `manga`),
  suppliers. A supplier is searchable only if its `supportedLanguages ∩ selectedLanguages` and
  `supportedTypes ∩ selectedTypes` are non-empty. Persist filters.
- Search runs on all selected suppliers **in parallel**; results grouped per supplier (horizontal rows),
  each row paginates independently (page 1 first, then 2, 3...; stop on empty page or error).
- Show "nothing found" when all suppliers returned empty.

## Collection / Library
- Groups by status in this order: `inProgress` (watching now), `latter` (later), `onHold`, `complete`.
- Text search over titles (word-prefix match, Ukrainian/Cyrillic aware, case-insensitive).
- Filters: status, media type (video/manga), supplier (only suppliers present in collection ∩ installed suppliers).
- Sort inside group: `priority` desc, then `lastSeen` desc.
- Item card: image, title, progress (episode N / total, progress bar), supplier badge.
- Updates live as sync events arrive (spec-03).

## Details
- Desktop/tablet layout: poster left, info right; mobile: poster header + scroll.
- Fields: title, secondary (original) title, image, description (expandable "read more"), additional info lines,
  similar items row (from the same supplier).
- Actions: **Watch/Read** (resume at `currentItem`), collection status selector, priority selector (when in collection),
  media-items (episodes/chapters) list grouped by `section`, per-item progress, per-item download button,
  "download all / season" (spec-08).
- Media items load lazily (`mediaItems` may trigger an FFI call). Show loading/error with retry.

## Theming
- Material 3, light/dark/system brightness, a set of named color schemes (persisted by name; default `olive`;
  legacy names include `crimson`, `monochrome` — keep names for settings compatibility where practical).
