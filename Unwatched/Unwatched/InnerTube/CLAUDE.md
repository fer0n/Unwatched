# InnerTube Layer — Maintenance Guide

Unwatched's native YouTube playback layer: a subset of SmartTubeIOS adapted for
Unwatched's architecture. Replaces the WKWebView player when
`Settings → Debug → useAVPlayer` is enabled.

---

## Design goals

**Keep `SmartTube/` and `Core/` vanilla** (sourced from upstream; minimise diff
so future merges are a straight diff-and-apply):
- Don't add Unwatched-specific logic inside those files.
- Put Unwatched-specific code in the Unwatched-owned files (`AVPlayerViewModel.swift`,
  `AVPlayerView.swift`, `WKHLSManager.swift`) and call into SmartTube files from there.
- If an upstream file needs a small change, document it in the diff table below and
  in a comment at the change site.

**Keep the AVPlayer layer decoupled:**
- No AV-player-specific imports/logic outside `InnerTube/`.
- All interaction with the rest of the app goes through `PlayerManager` (shared
  singleton) and `VideoService`/SwiftData — not direct coupling to other views.
- Pre-fetch, caching, and quality logic live inside `InnerTube/`; surrounding player
  UI only triggers them via `PlayerManager` state changes.

---

## Upstream source

- **Repo:** `../SmartTubeIOS` (sibling checkout, alongside this repo)
- **Package path:** `SmartTubeIOS/Sources/SmartTubeIOSCore/`
- **Last synced commit:** `1af1440` — update after every sync

---

## Directory layout

```
InnerTube/
  SmartTube/               ← nearly-vanilla SmartTubeIOS files; minimise changes
    Resources/yt.solver.core.min.js, yt.solver.lib.min.js
    AudioTrack.swift, HLSAudioLanguageParser.swift,
    YTHLSProxyLoader.swift, YouTubeWebViewHLSExtractor.swift
  Core/                    ← SmartTubeIOS API layer; adapted for Unwatched (see below)
    AppSubsystem.swift, CaptionTrack.swift, InnerTubeAPI*.swift,
    InnerTubeClients.swift, InnerTubeModels.swift, ITVideo.swift
  AVPlayerView.swift          ← Unwatched-owned
  AVPlayerViewModel.swift     ← Unwatched-owned
  WKHLSManager.swift          ← Unwatched-owned
  InnerTubeAPI+Metadata.swift ← Unwatched-owned (extension; not upstream)
  PlayerViewControllerRepresentable.swift
  CLAUDE.md
```

`InnerTubeAPI+Metadata.swift` adds `fetchVideoDescription(videoId:)` — a metadata-only
`/player` call that parses just `videoDetails.shortDescription`, never throws on
unresolvable streams. Backfills descriptions for videos added without one (e.g. from
search). Kept out of `Core/` so `InnerTubeAPI+Player.swift` stays vanilla.

### `SmartTube/` diffs vs upstream

| File | Change | Reason |
|---|---|---|
| `AudioTrack.swift` | Stripped `public` | Unwatched is not a Swift package |
| `HLSAudioLanguageParser.swift` | Stripped `public` | Unwatched is not a Swift package |
| `YouTubeWebViewHLSExtractor.swift` | Added `func cancel()` | Abort in-flight extraction when iOS client returns HLS first |
| `YouTubeWebViewHLSExtractor.swift` | Removed `static var isPreWarming` / `preWarm(videoId:)` | Uses `VideoPreloadCache` (not mirrored); Unwatched uses `WKHLSManager.preExtract` instead |
| `YTHLSProxyLoader.swift` | Logger subsystem → `appSubsystem` | Unwatched's OSLog subsystem constant |

---

## `Core/` file map & adaptations

| Upstream file | Unwatched file | Notes |
|---|---|---|
| `AppSubsystem.swift` | same | **Do NOT overwrite** — Unwatched-specific content |
| `CaptionTrack.swift` | same | Near drop-in; strip `package` |
| `Video.swift` | `ITVideo.swift` | Renamed `Video→ITVideo`, `Chapter→ITChapter`; extra fields — see below |
| `InnerTubeAPI.swift` | same | Drop-in; strip `package` |
| `InnerTubeAPI+Networking.swift` | same | Drop-in; strip `package` |
| `InnerTubeAPI+Player.swift` | same | Keep `import NaturalLanguage` + `originalAudioLanguage` detection — see below |
| `InnerTubeAPI+TextHelpers.swift` | same | Drop-in; strip `package` |
| `InnerTubeClients.swift` | same | Drop-in; strip `package` |
| `InnerTubeModels.swift` | same | Keep `originalAudioLanguage` in `PlayerInfo` — see below |
| `RetryWithBackoff.swift` | same | Near drop-in; logger swapped to OSLog on `appSubsystem` |
| `QualityRecoveryPolicy.swift` | same | `quality` param: `AppSettings.VideoQuality` → `Int` (0 = Auto) |

Not mirrored (app-level, not needed here): `BrowseViewModel`, `HomeViewModel`,
`SearchViewModel`, `PlaylistViewModel`, `DownloadStore`, `HLSManifestCache/Parser`,
`SponsorBlockService/SkipManager`, `iCloudSyncManager`, `LocalSubscription*`, `RSS*`,
`VideoPreloadCache`, etc.

Worth cherry-picking in the future:
- `WatchtimeTracker.swift` — wires up `generateCPN`/`reportPlaybackStarted`/`reportWatchtime`
- `VideoPreloadCache` + `BotGuardWebViewRunner` — unlocks upstream's full Phase -1a/-2/-1b
  3-way race (cached-WKHLS shortcut + BotGuard-minted CDN tokens). Big dependency surface;
  Unwatched's `primaryRace` (iOS-HLS vs WKWebView extraction) is the lightweight substitute.

### Per-file adaptations (re-apply on every sync)

**Global:** remove all `package ` access modifiers (SmartTubeIOSCore is a Swift
package; Unwatched isn't). Regex: `\bpackage\s+(func|var|let|class|struct|enum|init|typealias)\b`
→ drop the `package ` prefix.

**`ITVideo.swift`** (upstream `Video.swift`):
- Keep type names `ITVideo`/`ITChapter` everywhere (avoids SwiftData name conflicts).
- Preserve, don't overwrite: `hasPortraitThumbnail`, `notInterestedToken`,
  `dontLikeToken`, `hideChannelToken`, `deArrowTitle`, `deArrowThumbnailTimestamp`,
  `localFileURL`/`isDownloaded` (transient, excluded from `CodingKeys`), all
  `CodingKeys` (upstream has none), the thumbnail URL helpers extension.
- `formattedDuration` is inlined in the extension (upstream keeps it as a global
  `formatDuration` in `TimeFormatting.swift`, which doesn't exist in Unwatched).

**`InnerTubeModels.swift`:** `PlayerInfo` carries an extra `originalAudioLanguage: String`
field not in upstream — preserve it in the struct and in `applyingPoToken(_:)`.

**`InnerTubeAPI+Player.swift`:** keep `import NaturalLanguage` and the
`originalAudioLanguage` detection block inside `parsePlayerInfo` (uses
`NLLanguageRecognizer` on title+description). Keep `ITVideo(` constructor calls.

---

## How to upgrade

1. `cd ../SmartTubeIOS && git pull && git log --oneline -5`
2. Diff each mirrored file against its Unwatched counterpart, e.g.:
   ```
   diff ../SmartTubeIOS/Sources/SmartTubeIOSCore/<file>.swift Core/<file>.swift
   ```
   (same for `SmartTube/` files, path `.../Sources/SmartTubeIOSCore/<file>.swift`)
3. Apply upstream changes, then re-apply the adaptations above.
4. Update `AVPlayerView.swift` — see below.
5. Bump **Last synced commit** in this file.

---

## Playback orchestration (`AVPlayerViewModel+Loading.swift`)

`fetchAndPlay` mirrors the *attempt loop* of upstream `PlaybackViewModel.exhaustiveRetry`
(the bottom half, lines 241-454 upstream) — not the top-half Phase -1a/-2/-1b race,
which depends on `VideoPreloadCache`/`BotGuardWebViewRunner` (not mirrored). Flow:

1. **Fast path** — cached WKWebView HLS URL (`WKHLSManager.validEntry`).
2. **`primaryRace`** — iOS client HLS vs. in-flight WKWebView extraction; lightweight
   stand-in for upstream's BotGuard race, no extra infrastructure needed.
3. **`exhaustiveRetry`** — 3 attempts; each fires ~6 InnerTube clients in parallel
   (`withTaskGroup`: MWEB, TVEmbedded, WebSafari, iOS, Android, AndroidVR). HLS results
   play immediately as they arrive (first `.readyToPlay` wins via `attemptItem`);
   adaptive-only results queue by priority; muxed is the last resort, after which
   `backgroundQualityUpgrade` tries to swap up to HLS while playing.

Supporting pieces, all in `+Loading.swift`:
- **`attemptItem`** — replaces the item and awaits its first terminal status (18s
  timeout); equivalent of upstream's `attemptURL`.
- Each fetch wrapped in **`retryWithBackoff`** (transient `URLError` survival).
- **`APIError.ipBlocked`** from iOS/Android short-circuits the whole loop.
- **`handleItemFailure`** routes mid-playback `.failed` through
  **`qualityRecoveryAction`** (403/quality-cap/H.264 decode → re-`exhaustiveRetry`;
  else surface the error).

Keep this attempt-loop structurally aligned with upstream so a `diff` still maps.
Don't pull upstream's race/cache helpers without mirroring their infrastructure.

## AVPlayerView.swift

Consumes the Core layer. After a sync, check for:

1. New `APIError` cases in `InnerTubeModels.swift` → handle in `fetchAndPlay`'s `catch`.
2. New `PlayerInfo` fields → expose in the player if user-facing.
3. New `InnerTubeAPI` methods that improve reliability/quality, e.g.
   `fetchPlayerInfoAndroidVR` (audio-only, no PO token) or
   `fetchPlayerInfoForDownload` (muxed MP4, future download feature).
4. Quality switching — `rebuildCompositionForQuality` uses `VideoFormat.url` from
   `PlayerInfo.formats` directly; mirror upstream if format filtering/sorting changes.
5. Watch history — `generateCPN`/`reportPlaybackStarted`/`reportWatchtime` exist on the
   API but aren't wired up yet; integrate when `WatchtimeTracker` is cherry-picked.

---

## Key design constraints

- **`AVMutableComposition` vs HLS**: `preferredMaximumResolution` is silently ignored
  on composition items — always branch on `isUsingComposition` for quality changes.
- **VP9 exclusion**: filter `vp09` from every quality list/composition URL picker —
  causes decode failures on some Apple hardware.
- **`package` keyword**: never use it; Unwatched is not a Swift package.
- **NaturalLanguage**: `originalAudioLanguage` detection is Unwatched-only.
