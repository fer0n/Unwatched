# InnerTube Layer — Maintenance Guide

This directory contains Unwatched's native YouTube playback layer: a subset of
[SmartTubeIOS](file:///Users/michael.foerg/Documents/GitHub/SmartTubeIOS) adapted for
Unwatched's architecture. It replaces the WKWebView player when
`Settings → Debug → useAVPlayer` is enabled.

---

## Design goals

### Keep SmartTube files as vanilla as possible
Files under `SmartTube/` and `Core/` are sourced from the SmartTubeIOS upstream repo.
Minimise the diff against upstream so future merges are a straight diff-and-apply:
- **Do not** add Unwatched-specific logic inside those files.
- **Do** put Unwatched-specific code in the Unwatched-owned files (`AVPlayerViewModel.swift`,
  `AVPlayerView.swift`, `WKHLSManager.swift`) and call into SmartTube files from there.
- If an upstream file truly needs a small change (e.g. a one-line adapter), document it
  in the table below and in a comment at the change site.

### Keep the AVPlayer layer decoupled
The AV player (`AVPlayerView`, `AVPlayerViewModel`, `WKHLSManager`) should be self-contained:
- No AV-player-specific imports or logic in files outside the `InnerTube/` directory.
- All interaction with the rest of the app goes through `PlayerManager` (shared singleton)
  and the `VideoService` / SwiftData model context — not direct coupling to other views.
- Pre-fetch, caching, and quality logic all live inside `InnerTube/`; the surrounding
  player UI only triggers them via `PlayerManager` state changes.

---

## Upstream source

**Repo:** `/Users/michael.foerg/Documents/GitHub/SmartTubeIOS`
**Package path:** `SmartTubeIOS/Sources/SmartTubeIOSCore/`
**Last synced commit:** `9b8c4af`

Update this hash after every sync.

---

## Directory layout

```
InnerTube/
  SmartTube/               ← nearly-vanilla SmartTubeIOS files; minimise changes
    Resources/
      yt.solver.core.min.js
      yt.solver.lib.min.js
    AudioTrack.swift
    HLSAudioLanguageParser.swift
    YTHLSProxyLoader.swift
    YouTubeWebViewHLSExtractor.swift
  Core/                    ← SmartTubeIOS API layer; adapted for Unwatched (see below)
    AppSubsystem.swift
    CaptionTrack.swift
    InnerTubeAPI*.swift
    InnerTubeClients.swift
    InnerTubeModels.swift
    ITVideo.swift
  AVPlayerView.swift        ← Unwatched-owned
  AVPlayerViewModel.swift   ← Unwatched-owned
  WKHLSManager.swift        ← Unwatched-owned
  PlayerViewControllerRepresentable.swift
  CLAUDE.md
```

### SmartTube/ intentional diffs vs upstream

| File | Change | Reason |
|---|---|---|
| `AudioTrack.swift` | Stripped `public` access modifiers | Unwatched is not a Swift package |
| `HLSAudioLanguageParser.swift` | Stripped `public` access modifiers | Unwatched is not a Swift package |
| `YouTubeWebViewHLSExtractor.swift` | Added `func cancel()` | Needed to abort in-flight extraction when iOS client returns HLS first |
| `YouTubeWebViewHLSExtractor.swift` | Removed `static var isPreWarming` and `static func preWarm(videoId:)` | Uses `VideoPreloadCache` (not mirrored); Unwatched uses `WKHLSManager.preExtract` instead |
| `YTHLSProxyLoader.swift` | Logger subsystem → `appSubsystem` | Use Unwatched's OSLog subsystem constant |

---

## File map: SmartTubeIOSCore → Unwatched/InnerTube/Core

| SmartTubeIOSCore file | Unwatched file | Notes |
|---|---|---|
| `AppSubsystem.swift` | `AppSubsystem.swift` | **Do NOT overwrite** — Unwatched-specific content |
| `CaptionTrack.swift` | `CaptionTrack.swift` | Near drop-in; strip `package` |
| `Video.swift` | `ITVideo.swift` | Renamed `Video→ITVideo`, `Chapter→ITChapter`; extra fields; see below |
| `InnerTubeAPI.swift` | `InnerTubeAPI.swift` | Drop-in; strip `package` |
| `InnerTubeAPI+Networking.swift` | `InnerTubeAPI+Networking.swift` | Drop-in; strip `package` |
| `InnerTubeAPI+Player.swift` | `InnerTubeAPI+Player.swift` | Keep `import NaturalLanguage` + `originalAudioLanguage` detection; see below |
| `InnerTubeAPI+TextHelpers.swift` | `InnerTubeAPI+TextHelpers.swift` | Drop-in; strip `package` |
| `InnerTubeClients.swift` | `InnerTubeClients.swift` | Drop-in; strip `package` |
| `InnerTubeModels.swift` | `InnerTubeModels.swift` | Keep `originalAudioLanguage` in `PlayerInfo`; see below |
| `RetryWithBackoff.swift` | `RetryWithBackoff.swift` | Near drop-in; logger swapped to OSLog on `appSubsystem` |
| `QualityRecoveryPolicy.swift` | `QualityRecoveryPolicy.swift` | `quality` param: `AppSettings.VideoQuality` → `Int` (0 = Auto) |

Files in SmartTubeIOSCore that are **not** mirrored (app-level, not needed here):
`BrowseViewModel`, `HomeViewModel`, `SearchViewModel`, `PlaylistViewModel`,
`DownloadStore`, `HLSManifestCache/Parser`, `SponsorBlockService/SkipManager`,
`iCloudSyncManager`, `LocalSubscription*`, `RSS*`, `VideoPreloadCache`, etc.

Files that may be worth cherry-picking in the future:
- `WatchtimeTracker.swift` — wires up `generateCPN`/`reportPlaybackStarted`/`reportWatchtime`
- `VideoPreloadCache` + `BotGuardWebViewRunner` — would unlock upstream's full Phase -1a/-2/-1b
  3-way race (cached-WKHLS shortcut + BotGuard-minted CDN tokens). Big dependency surface;
  Unwatched's `primaryRace` (iOS-HLS vs WKWebView extraction) is the lightweight substitute.

---

## How to upgrade

1. Pull the upstream repo:
   ```
   cd /Users/michael.foerg/Documents/GitHub/SmartTubeIOS
   git pull
   git log --oneline -5
   ```

2. For `SmartTube/` files, diff and apply upstream changes then re-apply the intentional
   diffs listed in the table above:
   ```
   diff SmartTubeIOS/Sources/SmartTubeIOSCore/YTHLSProxyLoader.swift \
        /Users/michael.foerg/Documents/GitHub/Unwatched/Unwatched/Unwatched/InnerTube/SmartTube/YTHLSProxyLoader.swift
   diff SmartTubeIOS/Sources/SmartTubeIOSCore/YouTubeWebViewHLSExtractor.swift \
        /Users/michael.foerg/Documents/GitHub/Unwatched/Unwatched/Unwatched/InnerTube/SmartTube/YouTubeWebViewHLSExtractor.swift
   ```

3. For each `Core/` file (except `AppSubsystem.swift`), diff upstream vs Unwatched:
   ```
   diff SmartTubeIOS/Sources/SmartTubeIOSCore/<file>.swift \
        /Users/michael.foerg/Documents/GitHub/Unwatched/Unwatched/Unwatched/InnerTube/Core/<file>.swift
   ```

4. Apply `Core/` changes with the adaptations listed in the next section.

5. Update `AVPlayerView.swift` — see the AVPlayerView section below.

6. Update the **Last synced commit** hash in this file.

---

## Adaptations required on every sync

### Global find-replace
- Remove all `package ` access modifiers (SmartTubeIOSCore is a Swift package; Unwatched is not).
  Regex: `\bpackage\s+(func|var|let|class|struct|enum|init|typealias)\b` → drop the `package ` prefix.

### `ITVideo.swift` (upstream: `Video.swift`)
- Keep type names `ITVideo` and `ITChapter` everywhere (avoid SwiftData name conflicts).
- Unwatched extras that must be preserved — do not overwrite with upstream:
  - `hasPortraitThumbnail`, `notInterestedToken`, `dontLikeToken`, `hideChannelToken`
  - `deArrowTitle`, `deArrowThumbnailTimestamp`
  - `localFileURL` / `isDownloaded` (transient, excluded from `CodingKeys`)
  - All `CodingKeys` (upstream `Video` has no `CodingKeys` block)
  - The thumbnail URL helpers extension (`highQualityThumbnailURL`, `sdThumbnailURL`, etc.)
- `formattedDuration` is inlined in the extension (upstream keeps it in `TimeFormatting.swift`
  as a global `formatDuration` function that doesn't exist in Unwatched).

### `InnerTubeModels.swift`
- `PlayerInfo` carries an extra field `originalAudioLanguage: String` not in upstream.
  Preserve it in the struct definition and in `applyingPoToken(_:)`.

### `InnerTubeAPI+Player.swift`
- Keep `import NaturalLanguage` at the top.
- Keep the `originalAudioLanguage` detection block inside `parsePlayerInfo` (uses
  `NLLanguageRecognizer` to detect the video's primary language from title+description).
- Keep `ITVideo(` constructor calls using `ITVideo` (not `Video`).

---

## Playback orchestration (`AVPlayerViewModel+Loading.swift`)

`fetchAndPlay` mirrors the *attempt loop* of SmartTubeIOS `PlaybackViewModel.exhaustiveRetry`
(the bottom half, lines 241-454 upstream) — NOT the top-half Phase -1a/-2/-1b race, which depends
on `VideoPreloadCache` + `BotGuardWebViewRunner` (not mirrored). Flow:

1. **Fast path** — a cached WKWebView HLS URL (`WKHLSManager.validEntry`).
2. **`primaryRace`** — iOS client HLS vs. an in-flight WKWebView extraction. Unwatched's
   lightweight stand-in for upstream's BotGuard race; needs no extra infrastructure.
3. **`exhaustiveRetry`** — 3 attempts; each fires ~6 InnerTube clients in **parallel**
   (`withTaskGroup`): MWEB, TVEmbedded, WebSafari, iOS, Android, AndroidVR. HLS results play
   immediately as they arrive (first `.readyToPlay` wins via `attemptItem`); adaptive-only
   results are queued by priority; muxed is the last resort, after which
   `backgroundQualityUpgrade` tries to swap up to HLS while playing.

Supporting pieces, all in `+Loading.swift`:
- **`attemptItem`** — the per-stream primitive: replaces the item and *awaits* its first
  terminal status (with an 18 s timeout), so the loop only treats a stream as successful once it
  actually reaches `.readyToPlay`. The equivalent of upstream's `attemptURL`.
- Each fetch is wrapped in **`retryWithBackoff`** (transient URLError survival).
- **`APIError.ipBlocked`** from iOS/Android short-circuits the whole loop (no point retrying).
- **`handleItemFailure`** routes mid-playback `.failed` through **`qualityRecoveryAction`**
  (403 / quality-cap / H.264 decode → re-`exhaustiveRetry`; else surface the error).

When syncing upstream, keep this attempt-loop structurally aligned with upstream's so a `diff`
still maps. Do NOT pull the upstream race/cache helpers in without also mirroring their
infrastructure.

## AVPlayerView.swift

`AVPlayerView.swift` sits one level up (`InnerTube/AVPlayerView.swift`) and consumes the
Core layer. After a sync, check for:

1. **New `APIError` cases** in `InnerTubeModels.swift` → add handling in the `catch` block
   of `fetchAndPlay`.

2. **New `PlayerInfo` fields** → expose in the player if user-facing (e.g. new stream URL
   types, new metadata).

3. **New `InnerTubeAPI` methods** that improve playback reliability or quality, e.g.:
   - `fetchPlayerInfoAndroidVR` — audio-only fallback that doesn't need a PO token
   - `fetchPlayerInfoForDownload` — muxed MP4 for a future download feature

4. **Quality switching** — Unwatched's composition-mode quality switching
   (`rebuildCompositionForQuality`) uses `VideoFormat.url` directly from `PlayerInfo.formats`.
   If upstream changes how formats are filtered or sorted, mirror that logic here.

5. **Watch history** — `generateCPN`, `reportPlaybackStarted`, `reportWatchtime` are on the
   API but not yet wired up. When upstream's `WatchtimeTracker` is cherry-picked, integrate
   it in `fetchAndPlay` / the time-tracking task loop.

---

## Key design constraints

- **`AVMutableComposition` vs HLS**: `preferredMaximumResolution` is silently ignored on
  composition items. Always branch on `isUsingComposition` for quality changes.
- **VP9 exclusion**: filter `vp09` from every quality list and composition URL picker —
  it causes decode failures on some Apple hardware.
- **`package` keyword**: never use it; Unwatched is not a Swift package.
- **NaturalLanguage**: the `originalAudioLanguage` detection is Unwatched-only; upstream
  does not use it.
