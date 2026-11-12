---
name: firebase-collection-compat
description: 'Guardrails for any change to collection persistence, Firebase Realtime Database sync, profiles linking, or progress saving. Use whenever code reads/writes /collection/{uid} or the local collection store.'
---

# Firebase collection compatibility

Contract: [spec-03-collection-and-firebase-sync.instructions.md](../../instructions/spec-03-collection-and-firebase-sync.instructions.md).

## Checklist before committing
- [ ] Path is `collection/{uid}/{itemKey}`; `itemKey = supplier + id.replaceAll('/', '|').replaceAll('.', '')`.
- [ ] Written JSON keys are exactly: `id, supplier, title, image, mediaType, currentItem, currentSourceName,
      currentSubtitleName, positions, status, priority, lastSeen` — nothing else (no `tokens`, no profile ids).
- [ ] Enum strings: mediaType `video|manga`; status `none|latter|inProgress|complete|onHold`.
- [ ] `positions` written as map with **string** keys `"0","1",...`; values `{position, length}` ints.
- [ ] `lastSeen` is milliseconds since epoch (int), updated on every save.
- [ ] `status == none` → delete instead of save.
- [ ] Reader accepts `positions` as Map **or** List, numbers as int **or** double, missing fields → defaults.
- [ ] Merge: upsert only if `remote.lastSeen > local.lastSeen`; delete only if `remote.lastSeen >= local.lastSeen`;
      positions merged with remote winning per key.
- [ ] Tests in `test/collection/` pass with fixtures from `test/fixtures/legacy_collection_item*.json`.

## Reference implementation sketch

```dart
String itemKey(String supplier, String id) =>
    supplier + id.replaceAll('/', '|').replaceAll('.', '');

Map<int, MediaItemPosition> parsePositions(Object? raw) => switch (raw) {
  Map() => {
    for (final e in raw.entries)
      if (e.value != null) int.parse('${e.key}'): MediaItemPosition.fromJson(Map<String, Object?>.from(e.value as Map)),
  },
  List() => {
    for (var i = 0; i < raw.length; i++)
      if (raw[i] != null) i: MediaItemPosition.fromJson(Map<String, Object?>.from(raw[i] as Map)),
  },
  _ => const {},
};
```

## Manual verification
1. Sign in with the same Google account in the legacy app and the rewrite.
2. Change status/progress in one; confirm it appears in the other within seconds, with positions preserved.
3. Delete in one; confirm removal in the other.
