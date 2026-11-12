---
description: 'Use when working on downloads, download scheduler (parallel + sequential per show), HLS download, offline storage layout, offline mode.'
applyTo: 'lib/features/downloads/**'
---

# Spec 08 — Downloads and offline mode

## 8.1 Download manager

- One manager service (keepAlive provider) with a persistent queue (survives app restart; unfinished tasks resume).
- **Parallel downloading**: global concurrency limit `maxConcurrent` (setting, default **3**, range 1–5).
  Different contents download in parallel up to the limit.
- **Sequential download of TV shows**: "Download all" / "Download season" on a multi-item content enqueues its
  episodes as one **content group**. A group runs **at most one task at a time**, strictly in episode order
  (ascending item index); when an episode finishes (or fails after retries), the next one starts automatically.
  Single-episode downloads of the same content join the same group.
- Scheduler picks the next runnable task: FIFO across groups, respecting the global limit and the
  one-per-group rule. Covered by unit tests (pure Dart, fake clock/transport).
- Task states: `queued → started → completed | failed | canceled`; progress 0..1 and speed (bytes/s).
  Retries: 3 with backoff on network/5xx; no retry on 4xx (link expired → re-resolve the source once, then fail).
- Cancel: per task, per group, all. Delete removes files.
- Task id: `"${supplier}_${id}_${itemIndex}"`; content prefix `"${supplier}_${id}"`.
- Android: run inside a **foreground service** (type `dataSync`) with a progress notification so downloads continue
  when the app is backgrounded; request notification permission and battery-optimization exemption politely.
- Desktop: run in-process (isolate or async), same scheduler.
- UI: download queue indicator (badge in top bar / account menu), queue sheet with progress, speed, cancel.

## 8.2 What is downloaded

| Source kind | Handling | Output |
|-------------|----------|--------|
| Video, progressive (mp4 etc.) | HTTP GET with source headers, `Range` resume into `.part` file, rename on success | `<desc>.mp4` |
| Video, HLS | Parse master → highest-bandwidth variant (fallback to next) → download segments sequentially → **dejunk every clear TS segment** (always, regardless of `hlsProxy`), AES-128 decrypt-then-dejunk, `EXT-X-BYTERANGE`, fMP4 init + media untouched — all per [spec-12 §12.5](spec-12-hls-ts-dejunking.instructions.md) → one file playable by media_kit | `<desc>.mp4` |
| Subtitle | Plain GET | `<desc>.vtt` |
| Manga | Download all pages (bounded parallelism ~4) | folder `pages_<desc>/` with ordered files |

The user picks the source in a dialog (sources list, icon per kind); the selected subtitle of the collection
item is downloaded alongside the video when available.

## 8.3 Offline storage layout (keep legacy layout for continuity)

```
<downloadsDir>/
  <supplier>_<Uri.encodeComponent(id)>/
    details.json                         {title, secondaryTitle, image, mediaType, additionalInfo, description}
    <itemIndex>/
      <Uri.encodeComponent(desc)>.mp4
      <Uri.encodeComponent(desc)>.vtt
      pages_<Uri.encodeComponent(desc)>/
```

- `downloadsDir`: desktop — user-selectable folder (setting), default `<Downloads>/strumok`; Android —
  `<Downloads or app documents>/strumok` (not user-selectable).
- If the configured custom folder no longer exists, reset to default.
- Store `details.json` when the first download of a content starts.
- Offline items screen (`/downloads`): list contents with poster, title, disk usage; open → offline details;
  delete content (confirm). Per-item delete from the details episode list.

## 8.4 Offline mode

- Global switch (account menu + settings), persisted. Also auto-suggest it when the network is unavailable.
- In offline mode:
  - Home shows downloaded contents; Search is disabled with an explanation.
  - Details come from `details.json`; media items = downloaded item indexes (title "N").
  - Player/reader use local files as sources (`description` = decoded file name), progress still saved to the
    active profile's local collection (synced later when online).
- Online mode with downloaded items: details merge supplier data with offline availability — the local
  source appears first in the source list and is preferred for playback.
