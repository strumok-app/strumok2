---
description: 'Use when working on profiles / tenants: multiple local collections with different Google accounts on shared TV or tablet, profile picker, per-profile Firebase apps.'
applyTo: 'lib/features/profiles/**'
---

# Spec 05 — Profiles (multi-tenant local collections)

Goal: a shared device (family TV, shared tablet) can hold **several independent local collections**, each
optionally linked to a **different Google account**, and switch between them without signing out.

## 5.1 Model

```dart
class Profile {
  final String id;            // uuid v4, immutable
  final String name;          // user-editable display name
  final int colorSeed;        // avatar color; avatar = first letter of name (or Google photo when linked)
  final String? firebaseUid;  // set when linked to a Google account
  final String? accountName;  // cached displayName for the picker
  final String? accountPhotoUrl;
  final DateTime createdAt;
}
```

- Profiles list + `activeProfileId` stored in app-level (device) storage.
- First launch creates a default profile `"Основний"/"Main"` and makes it active.
- **Legacy upgrade**: if a legacy local collection / Firebase session exists, attach it to the default profile.

## 5.2 Isolation — MUST

| Data | Scope |
|------|-------|
| Collection (local store + Firebase sync) | **per profile** |
| Firebase auth session | **per profile** — initialize a separate named Firebase app per linked profile (e.g. `profile-<id>`) with its own persistence dir `<appSupport>/firebase/<profileId>`, so each profile keeps its own refresh token and switching does not require re-login |
| Search history | per profile |
| Theme, language, player settings, supplier settings/bundle, downloads folder | device-wide |
| Downloaded files | device-wide (shared); playback progress is still written to the active profile's collection |

- Two profiles must not link the same `firebaseUid` (show an error; offer to switch to the existing profile).
- Firebase data layout is unchanged: each linked profile syncs `/collection/{its uid}` (spec-03).

## 5.3 Riverpod wiring

- `profilesProvider` (keepAlive notifier): list, create, rename, delete, link/unlink account.
- `activeProfileProvider`: the selected profile; changing it **invalidates** the collection repository,
  sync subscription, auth user, search history providers (they `watch` the active profile).
- `collectionRepositoryProvider` = f(activeProfile, offlineMode) → local-only or local+Firebase.
- Switching profile while the player is open: stop the player (and floating/PiP) first, flush pending progress.

## 5.4 UI

- **Profile picker** shown at startup when there are ≥ 2 profiles (TV-friendly grid of large focusable avatars,
  "Add profile" tile). Skip when only one profile exists. Option "remember last profile / don't ask" in settings.
- Account menu: active profile on top, "Switch profile", "Manage profiles".
- Manage profiles (settings sub-page): add, rename, change color, link Google account (or TV pairing code on TV),
  unlink, delete (confirm; deleting removes the local collection only — never deletes Firebase data).
- On TV, linking a profile uses the pairing-code flow (spec-04 §4.3) into that profile's Firebase app.

## 5.5 Out of scope (for now)
PIN-protected/kids profiles, per-profile content filters. Design the model so they can be added later.
