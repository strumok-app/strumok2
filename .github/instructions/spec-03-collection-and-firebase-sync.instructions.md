---
description: 'Use when working on collection items, local collection store, Firebase Realtime Database sync, merge rules, progress saving. Compatibility contract for /collection/{uid} JSON.'
applyTo: 'lib/features/collection/**'
---

# Spec 03 — Collection and Firebase realtime sync (COMPATIBILITY CONTRACT)

The collection is **local-first**: the UI always reads from a local store; when a profile is linked to a
Google account and the app is online, the local store is mirrored to Firebase Realtime Database in realtime.
Existing users' data in Firebase **MUST** load unchanged, and items written by the new app **MUST** be readable
by the legacy app.

## 3.1 Firebase RTDB layout — MUST

```
/collection/{firebaseUid}/{itemKey} = CollectionItemJson
```

`itemKey` = **`supplier + id.replaceAll("/", "|").replaceAll(".", "")`**
(no separator between supplier and id; `/` → `|`, `.` removed — RTDB key restrictions). Reproduce exactly,
including the lack of a separator. Use the same function for the local store key.

## 3.2 Item JSON — MUST (field names, types, enum spellings)

```json
{
  "id": "some/content-id",
  "supplier": "uakino",
  "title": "Title",
  "image": "https://...",
  "mediaType": "video",
  "currentItem": 3,
  "currentSourceName": "Server 1 (UA)",
  "currentSubtitleName": null,
  "positions": {
    "0": { "position": 1310, "length": 1325 },
    "3": { "position": 412,  "length": 1400 }
  },
  "status": "inProgress",
  "priority": 1,
  "lastSeen": 1731222222000
}
```

| Field | Type | Rules |
|-------|------|-------|
| `id`, `supplier`, `title`, `image` | string | required |
| `mediaType` | `"video"` \| `"manga"` | missing → `video` |
| `currentItem` | int | index of media item (0-based); missing → 0 |
| `currentSourceName` | string? | video/manga source `description` |
| `currentSubtitleName` | string? | subtitle source `description` |
| `positions` | map `"<itemIndex>" → {position:int, length:int}` | video: seconds; manga: page index / page count. Missing → `{}` |
| `status` | `"none"` \| `"latter"` \| `"inProgress"` \| `"complete"` \| `"onHold"` | note the legacy spelling **`latter`** (means "watch later"); missing → `none` |
| `priority` | int `0` low, `1` normal, `2` high | missing → 1 |
| `lastSeen` | int (ms since epoch) | conflict-resolution clock |

Reading MUST be tolerant:
- RTDB may coerce a map with integer-like keys into a **JSON array** (with `null` holes). Accept both
  `Map<String, dynamic>` and `List<dynamic>` for `positions` (array index = item index; skip nulls).
- Numbers may arrive as `double`; convert with `(num).toInt()`.
- Unknown extra fields must be ignored (and preserved if cheap).
- Never write fields that the legacy app does not know into RTDB items. Local-only fields (e.g. search
  `tokens`) stay local.

## 3.3 Write rules — MUST

- Saving an item with `status == none` **deletes** it (locally and remotely).
- Every save sets `lastSeen = now()` (ms).
- Save = write locally first (UI updates immediately), then `set()` the full item JSON at its RTDB path.
- Delete = remove locally and `remove()` the RTDB path.
- Progress update rules (reduce write volume):
  - Video: persist position only when `position > 10s` **and** differs from stored position by `> 10s`,
    excluding the final `60s` when length is known (fixed constant; preserve the previously saved position);
    doing so sets `status = inProgress` only when the item is not in the collection (`status == none`); an
    existing status is kept (deliberate change: legacy overwrote any status with `inProgress`).
  - Video length: when known (`> 0`), store it; clamp position to `length - 1`; same status rule.
  - Manga: persist when page index changes; same status rule.
  - Changing `currentItem`, `currentSourceName`, `currentSubtitleName`, `status`, `priority` persists immediately.
  - `priority` can only be changed when `status != none`.
- When an item is opened from details, refresh its `title`/`image` from fresh supplier details.

## 3.4 Realtime sync / merge rules — MUST

Subscribe to `/collection/{uid}` with `keepSynced(true)` and RTDB persistence enabled; handle
`onChildAdded`, `onChildChanged`, `onChildRemoved`:

- **Upsert (added/changed)**: apply remote item only if `remote.lastSeen > local.lastSeen` (missing = 0).
  When applying, merge `positions` = `local.positions ∪ remote.positions` with **remote winning per key**.
- **Remove**: delete local item only if `remote.lastSeen >= local.lastSeen`.
- Emit a change notification after each applied change so collection providers refresh.
- On first link of a profile to an account (new behavior, not in legacy), push local items whose `lastSeen`
  is newer than remote (or missing remotely) so offline-created items are not lost.

## 3.5 Local store

- Storage engine is free choice (sembast/drift/sqlite). One logical store per **profile** (spec-05).
- Key = `itemKey` from §3.1. Value = item JSON + local-only `tokens` (lowercased words of title matched by
  `[\u0400-\u04FF\w]+`) for prefix search.
- Query: optional word-prefix filter (OR of words), sort by `priority` desc then `lastSeen` desc; then
  filter in memory by status / mediaType / supplier.
- Optional nice-to-have (desktop only — on Android the new `app.strumok` cannot read `app.cloud_hook` data):
  one-time import from the legacy sembast DB (`<legacy appSupportDir>/database.db`, store `collection`,
  same key/value format) into the default profile.

## 3.6 Offline mode

When the global offline-mode switch is on (or the profile has no linked account) use the local repository only.
Turning offline mode off re-attaches the Firebase sync and reconciles via §3.4.

## 3.7 Required tests
- JSON round-trip with fixture produced by the legacy app; byte-equivalent key set on write.
- `itemKey` sanitization cases: `/`, `.`, unicode.
- Merge matrix: remote newer/older/equal for upsert and remove; positions merge.
- `positions` as array input.
