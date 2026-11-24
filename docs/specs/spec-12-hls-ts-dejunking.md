---
description: 'Use when working on HLS handling: MPEG-TS segment dejunking (stripping fake PNG/JPEG/junk prefixes), the local HLS proxy used for hlsProxy sources, HLS playlist parsing/rewriting, AES-128 segments, fMP4, or HLS video downloads.'
applyTo: 'lib/core/hls/**, lib/features/player/data/**, lib/features/downloads/data/**'
---

# Spec 12 — HLS TS segment dejunking (and the HLS proxy)

**Dejunking is the feature; the HLS proxy is just one of its consumers.** The same dejunk implementation MUST be
used by (1) playback through the local HLS proxy and (2) HLS video downloads.

## 12.1 Why

Some video hosts disguise HLS MPEG-TS segments as other files to get past hotlink protection/CDN filters:
segments are served with fake extensions and content types (e.g. `.png`, `.jpg`, `image/*`), and the body
**starts with a junk prefix** — typically a real 1×1 PNG/JPEG "tracking pixel" or other garbage — followed by the
real TS packets.

Consequences without dejunking:
- **Playback**: FFmpeg/mpv probes the first bytes, detects an image (or nothing), and fails, stutters or loses sync.
- **Downloads**: concatenating raw segments produces a file with junk between every segment; it's broken or unseekable.

Dejunking = find where the real MPEG-TS stream starts in each segment and drop everything before it.

## 12.2 Algorithm — MUST (shared, pure Dart)

Location: `lib/core/hls/ts_dejunker.dart` (no Flutter/IO imports; streaming; unit-tested). Used by the proxy and
the downloader; never duplicated.

Constants: TS packet size **188** bytes, sync byte **0x47**.
State per segment: `syncFound` (bool), `pending` buffer, `filteredBytes` (number of junk bytes dropped).

```text
feed(chunk) -> bytesToEmit | null
  if syncFound: return chunk                       # zero-copy passthrough after sync
  pending += chunk
  if pending.length < 2*188 + 1: return null       # need ≥ 3 packet starts to confirm
  for i in 0 .. while i + 2*188 < pending.length:
    if pending[i] == pending[i+188] == pending[i+376] == 0x47:
      syncFound = true; filteredBytes = i
      out = pending[i..]; pending.clear(); return out
  return null                                       # keep buffering

finish() -> bytesToEmit | null                       # end of segment
  if syncFound: return null
  # short segment (< 3 packets): accept the last 2, else the last 1, packets aligned to the END
  for k in [2, 1]:
    off = pending.length - k*188
    if off >= 0 and every packet start p in off, off+188, … has
       pending[p] == 0x47 and (pending[p+3] & 0x30) != 0:   # adaptation_field_control != 0 (reserved)
      syncFound = true; filteredBytes = off; return pending[off..]
  throw FormatException("No MPEG-TS sync found in segment")
```

Rules:
- **Three** sync bytes exactly 188 apart are required to confirm sync; junk often contains `0x47` by chance
  (tests use a junk prefix that starts with `0x47`).
- Only the **leading** junk is removed; nothing after the confirmed sync point is touched.
- Clean TS is a no-op (`filteredBytes == 0`, output byte-identical).
- Only for **clear MPEG-TS**. Never feed it fMP4 data or encrypted bytes (decrypt first).
- A segment with no TS sync is an **error** for that segment (proxy → 502, download → retry, then fail), never silently emitted.
- Log `filteredBytes` at fine/info level when > 0.
- New safety rule (not in legacy): if `pending` grows beyond 2 MiB without sync, fail the segment.
- Performance: avoid rescanning from 0 on every chunk (resume from the last checked offset).

## 12.3 Where dejunking applies — MUST

| Segment type | Playback (proxy) | Download |
|--------------|------------------|----------|
| Clear MPEG-TS | **dejunk** | **dejunk** |
| AES-128 encrypted TS (`EXT-X-KEY` METHOD ≠ NONE) | passthrough (player decrypts; key URIs untouched) | decrypt, **then dejunk** (new: the legacy app skipped dejunking after decryption) |
| TS with `EXT-X-BYTERANGE` | passthrough, origin `Range` forwarded (ranges must stay aligned with the origin) | fetch the range, then dejunk |
| fMP4 (`EXT-X-MAP` init + media) | passthrough | no dejunk; write the init segment once per distinct map, then media |

## 12.4 Consumer 1 — local HLS proxy for playback (`hlsProxy == true`)

The supplier sets `hls_proxy: true` on a `Video` source when its CDN serves disguised/junked segments
(spec-02). Only those sources are routed through the proxy; others play directly (no overhead).

Server:
- Bind **loopback only** (`127.0.0.1`), **ephemeral port** (legacy used fixed port 16888 — can collide); one server per
  video backend, started before playback and stopped when the backend is disposed.
- Player URL: `http://127.0.0.1:<port>/master?url=<encoded upstream m3u8>`.

Endpoints:
- `GET /master?url=` and `GET /stream?url=` — fetch the playlist upstream (no `Range`), rewrite it, reply
  `application/vnd.apple.mpegurl` with a known `Content-Length` and local `Range` support.
- `GET /segment?url=<enc>[&format=fmp4][&passthrough=true]` — fetch the segment and either dejunk (default) or pass through.

Playlist rewriting:
- Resolve relative URIs against the playlist URL.
- Playlist with `#EXT-X-STREAM-INF` (master): rewrite variant URIs → `/stream?url=…`.
- Media playlist: rewrite segment URIs → `/segment?url=…`.
  - `#EXT-X-KEY`: keep the line unchanged (the player fetches keys from the origin). METHOD ≠ NONE marks the following
    segments `passthrough=true` until a later `#EXT-X-KEY` with METHOD=NONE.
  - `#EXT-X-BYTERANGE`: mark only the **next** segment `passthrough=true`.
  - `#EXT-X-MAP`: rewrite its `URI` → `/segment?url=…&format=fmp4`; all following segments get `format=fmp4`.

Segment responses:
- `Content-Type: video/mp2t` (TS) or `video/mp4` (fMP4) — this also hides the fake image type/extension from the player.
- Dejunked TS:
  - upstream length known and request has no `Range` (or `bytes=0-`): stream it, sending headers once sync is found,
    with `Content-Length = upstreamLength − filteredBytes` (`206` + `Content-Range` for `bytes=0-`);
  - otherwise buffer the whole dejunked segment and answer `Range` against the **dejunked** bytes.
- Passthrough: forward `Range`, copy `Content-Range` / `Accept-Ranges`; buffer if upstream length unknown.
- **Always send a known `Content-Length`** (never chunked): FFmpeg's reconnect options treat EOF on an
  unknown-length response as a dropped connection and refetch it.
- Upstream headers: forward the player's request headers (source `headers` are passed to mpv and arrive at the proxy)
  except hop-by-hop headers (`connection`, `keep-alive`, `proxy-authenticate`, `proxy-authorization`, `te`, `trailers`,
  `transfer-encoding`, `upgrade`, `host`); forward `Range`/`If-Range` only for passthrough.
- Errors: missing/invalid `url` → 400; upstream ≥ 400 → same status; dejunk failure or network error → 502.

## 12.5 Consumer 2 — HLS downloads (always dejunk)

- The downloader dejunks **every clear TS segment regardless of `hlsProxy`** (it must not trust extensions or
  content types; dejunking is a no-op for clean TS).
- HLS detection: URL ends with `.m3u8`, content type `application/vnd.apple.mpegurl` / `application/x-mpegurl`,
  or body starts with `#EXTM3U` (sniffing is new).
- Master playlist: try variants by bandwidth (highest first); on failure fall back to the next variant.
- Per segment: send source headers (+ `Range` for byte ranges), retry 3× with 10 s delay, then fail the task.
- AES-128-CBC: fetch the key (with source headers), IV from `IV=` attribute, otherwise the segment's media sequence
  number as a 16-byte big-endian value (RFC 8216; the legacy app used a zero IV).
- Write dejunked output progressively to `<file>.part`, rename on success; progress = segments done / total.
  Output file name keeps `.mp4` (offline layout, spec-08) even when the content is a TS/fMP4 concatenation;
  media_kit probes the actual container.

## 12.6 Tests — MUST (port the legacy cases)

Packet generator: 188-byte packets with `byte[0] = 0x47`, `byte[3] = 0x10 | (i % 16)`, payload filled with `i+1`.

Dejunker:
- Clean 5-packet segment split at **every** chunk boundary → output identical, `filteredBytes == 0`, nothing pending.
- 3 packets: feeding 376 bytes → `null`; the 377th byte → emits the first 377 bytes; the rest passes through unchanged.
- 701-byte junk prefix **starting with 0x47** + 4 packets, split at every boundary → output == packets, `filteredBytes == 701`.
- 1 and 2 packets with junk of 0 / 17 / 701 bytes fed byte-by-byte → flushed by `finish()`.
- Empty, 800 × `0x99`, 187 bytes of a packet, a 188-byte buffer with only the sync byte → `finish()` throws.

Proxy (against a local upstream test server):
- Clean short TS forwarded byte-identical with `Content-Length`.
- Junk stripped for known-length and chunked upstreams; response is length-framed.
- Playlists have known length and serve local ranges (`bytes=0-`, mid ranges).
- TS ranges answered against dejunked bytes.
- Encrypted segments passed through; METHOD=NONE turns dejunking back on.
- `EXT-X-BYTERANGE` ranges forwarded to the origin.
- fMP4 init + media passed through unchanged.

Downloads:
- Junked TS playlist → output file equals the concatenation of clean packets.
- Encrypted + junked TS → decrypted and dejunked.
- fMP4 playlist → init once + media, untouched.
