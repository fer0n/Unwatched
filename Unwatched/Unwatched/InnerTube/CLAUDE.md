# InnerTube Layer — Maintenance Guide

Unwatched's native YouTube playback layer: a subset of SmartTubeIOS adapted for
Unwatched's architecture. Replaces the WKWebView player when
`Settings → Debug → useAVPlayer` is enabled.

**Platforms:** iOS, visionOS and macOS all run this player. The two places platforms diverge
are `PlayerViewControllerRepresentable.swift` (a UIKit and an AppKit host over one shared
`PlayerLayerController`) and `PlayerAudioSession` in `AVPlayerViewModel.swift` (`AVAudioSession`
is unavailable on macOS). macOS also has no auto-PiP and never pauses a layer-attached player on
backgrounding, so the background-detach workaround is UIKit-only. Pinch-to-zoom is iOS-only —
`ZoomPanModifier` no-ops on visionOS and macOS.

**The API layer lives in the shared framework:**
`UnwatchedShared/UnwatchedShared/InnerTube/Core/`. Everything else — the WKWebView extraction,
the AVPlayer view models, the player UI — stays here in the app target, since it needs WebKit and
the app's own types. tvOS has no WKWebView, so it drives `InnerTubeAPI` directly
(`Unwatched/tvOS/Player/TvStreamResolver.swift`); this split is what lets it.

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
- Exception, both directions, for seamless player switching (see `PlayerSwitchManager`):
  `AVPlayerPrefetchManager.shared.warmUp` is called from `PlayerSwitchManager` to
  pre-build the *current* video before any `AVPlayerViewModel` exists — hence the
  singleton — and `AVPlayerViewModel`, `PlayerScrubberOverlay` and `BackgroundPlaybackManager`
  read `PlayerSwitchManager.shared` to tell a hand-over apart from a teardown.
- Pre-fetch, caching, and quality logic live inside `InnerTube/`; surrounding player
  UI only triggers them via `PlayerManager` state changes.

---

## Upstream source

- **Repo:** `../SmartTubeIOS` (sibling checkout, alongside this repo)
- **Package paths** (inside that repo): `SmartTubeIOS/Sources/SmartTubeIOSCore/` for `Core/` and
  `AudioTrack`/`HLSAudioLanguageParser`; `SmartTubeIOS/Sources/SmartTubeIOS/Services/` for
  `YTHLSProxyLoader` and `YouTubeWebViewHLSExtractor`
- **Last synced commit:** `e659ce9` — update after every sync
- **Upstream is swift-formatted since `a1dbf49`**, Unwatched's copies are not, so a whole-file
  `diff` is mostly line-wrapping noise. Diff by commit instead (see *How to upgrade*).

---

## Directory layout

```
UnwatchedShared/UnwatchedShared/InnerTube/
  Core/                    ← SmartTubeIOS API layer; adapted for Unwatched (see below)
    AppSubsystem.swift, CaptionTrack.swift, InnerTubeAPI*.swift,
    InnerTubeClients.swift, InnerTubeModels.swift, ITVideo.swift,
    RetryWithBackoff.swift, QualityRecoveryPolicy.swift, SearchFilter.swift,
    HLSManifestParser.swift (partial)
  Channel/, HomeFeed/      ← Unwatched-owned InnerTubeAPI extensions (channel videos, live
                             streams, home feed); not upstream

Unwatched/Unwatched/InnerTube/
  SmartTube/               ← nearly-vanilla SmartTubeIOS files; minimise changes
    Resources/yt.solver.core.min.js, yt.solver.lib.min.js
    AudioTrack.swift, HLSAudioLanguageParser.swift,
    YTHLSProxyLoader.swift, YouTubeWebViewHLSExtractor.swift
  AVPlayerView.swift          ← Unwatched-owned
  AVPlayerViewModel.swift     ← Unwatched-owned
  AVPlayerViewModel+Fallback.swift ← Unwatched-owned (unplayable-verdict handling)
  WKHLSManager.swift          ← Unwatched-owned
  InnerTubeAPI+Metadata.swift ← Unwatched-owned (extension; not upstream)
  PlayerViewControllerRepresentable.swift  ← UIKit + AppKit hosts
  CLAUDE.md
```

`Core/` is compiled into `UnwatchedShared` via its file-system-synchronized group, so new files
there need no project edits. Files added to `Unwatched/Unwatched/InnerTube/` still need explicit
references in `Unwatched.xcodeproj`.

`InnerTubeAPI+Metadata.swift` adds `fetchVideoMetadata(videoId:)` — a metadata-only
`/player` call that parses just `videoDetails` (description, channel id, channel title), never
throws on unresolvable streams. Backfills what a video was added without (e.g. from search,
whose results carry no description, and whose Shorts carry no channel). Kept out of `Core/` so
`InnerTubeAPI+Player.swift` stays vanilla.

`InnerTubeAPI+Search.swift`'s `fetchChannelAvatarURL(channelId:)` delegates to
`UnwatchedShared/UnwatchedShared/Service/ChannelAvatarService.swift` instead of making the
`browse` request itself — the Share Extension needs this same channel-avatar fetch (for its
channel-share preview) but can't import InnerTube, so the one request lives in the shared
package and both call into it. If it starts failing, update the embedded WEB client version
in `ChannelAvatarService.swift`, not here.

`InnerTubeAPI+Search.swift`'s `parseSearchPage(from:)` is internal instead of `private`, so
`InnerTube/HomeFeed/` can parse the home feed and related videos with it. Those responses are
fetched from inside a hidden youtube.com web view (`HomeFeedService`), so a signed-in session
never leaves WebKit — see `YoutubeCookieFilter` for why the app's own requests can't carry it.
Re-apply the `private` → internal change on every sync.

`parseLockupViewModel` also reads the duration from the thumbnail badge
(`contentImage.thumbnailViewModel.overlays[].thumbnailBottomOverlayViewModel.badges[]`); upstream
passes `duration: nil` there, so lockup results (most home, related and many search results)
showed no length. Re-apply on every sync.

### `SmartTube/` diffs vs upstream

| File | Change | Reason |
|---|---|---|
| `AudioTrack.swift` | Stripped `public` | Unwatched is not a Swift package |
| `HLSAudioLanguageParser.swift` | Stripped `public` | Unwatched is not a Swift package |
| `YouTubeWebViewHLSExtractor.swift` | Added `func cancel()` | Abort in-flight extraction when iOS client returns HLS first |
| `YouTubeWebViewHLSExtractor.swift` | Removed `static var isPreWarming` / `preWarm(videoId:)` | Uses `VideoPreloadCache` (not mirrored); Unwatched uses `WKHLSManager.preExtract` instead |
| `YouTubeWebViewHLSExtractor.swift` | Removed unused JS helper `extractFnFromJSArray` from `interceptorJS` | Never called; `solveNFromPlayerJS` solves the n-challenge via the bundled EJS solver (`jsc`) instead |
| `YTHLSProxyLoader.swift` | Logger subsystem → `appSubsystem` | Unwatched's OSLog subsystem constant |
| `YTHLSProxyLoader.swift`, `YouTubeWebViewHLSExtractor.swift` | Added `import UnwatchedShared` | `appSubsystem` moved there with `Core/` |

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
| `SearchFilter.swift` | same | Drop-in; strip `package` |
| `HLSManifestParser.swift` | same | **Partial** — only `filterHLSMasterManifest` and its two helpers (tvOS uses it); the parsers upstream also keeps there aren't used |
| `InnerTubeAPI+Browse.swift`, `+VideoRenderers.swift` | `InnerTubeAPI+Search.swift` | **Not a mirror** — a trimmed port of the search/lockup parsers only (see above). Pull renderer fixes by hand when they touch `videoRenderer`/`reelItemRenderer`/`lockupViewModel` parsing |

Not mirrored (app-level, not needed here): `BrowseViewModel`, `HomeViewModel`,
`SearchViewModel`, `PlaylistViewModel`, `DownloadStore`, `HLSManifestCache`,
`SponsorBlockService/SkipManager`, `iCloudSyncManager`, `LocalSubscription*`, `RSS*`,
`VideoPreloadCache`, etc.

**visionOS client** (`fetchPlayerInfoVisionOS`, `InnerTubeClients.VisionOS`) — yt-dlp's
first-choice JS-less client, no PO token. Probed 2026-10-14: it returned `hlsManifestUrl` for every
playable test video (H.264 to 1080p, VP9 above that to 4K; 1080p segments at ~25× realtime), while
the iOS client returned HLS for 1 in 10 ("Stream URLs require decryption" for the rest). tvOS
plays it first (`TvStreamResolver.hdItem`), with `TvHLSMasterLoader` passing the master through
`filterHLSMasterManifest` to keep only `avc1` ≤ 1080p; if that item fails before it starts, tvOS
falls back to the old 360p chain. The iOS player doesn't use it yet — a candidate for
`primaryRace`/`exhaustiveRetry`, which would give HD without waiting for the WKWebView extraction.
Upstream applies the same filter inside `YTHLSProxyLoader` (`2320131`); that loader change was
not pulled, since tvOS doesn't compile the loader (`#if canImport(WebKit)`).

Worth cherry-picking in the future:
- `WatchtimeTracker.swift` — wires up `generateCPN`/`reportPlaybackStarted`/`reportWatchtime`.
  Upstream rewrote the pings (PR #152 and follow-ups): they now need the `ei`/`vm`/`of` session
  params from `PlaybackTrackingURLs` (`fetchHistoryTrackingURLs`) plus `lengthSeconds`, and are
  skipped without them.
- `VideoPreloadCache` + `BotGuardWebViewRunner` — unlocks upstream's full Phase -1a/-2/-1b
  3-way race (cached-WKHLS shortcut + BotGuard-minted CDN tokens). Big dependency surface;
  Unwatched's `primaryRace` (iOS-HLS vs WKWebView extraction) is the lightweight substitute.

### Per-file adaptations (re-apply on every sync)

**Global:** rewrite every `package ` access modifier as `public ` — `Core/` is its own module
(`UnwatchedShared`), and the app target reaches these declarations across the module boundary.
Regex: `\bpackage\s+(func|var|let|class|struct|enum|init|typealias)\b` → `public $1`. A public
struct needs its stored properties and any memberwise construction site public too; a public
method's parameter and result types must be public as well.

**`ITVideo.swift`** (upstream `Video.swift`):
- Keep type names `ITVideo`/`ITChapter` everywhere (avoids SwiftData name conflicts).
- Preserve, don't overwrite: `hasPortraitThumbnail`, `notInterestedToken`,
  `dontLikeToken`, `hideChannelToken`, `deArrowTitle`, `deArrowThumbnailTimestamp`,
  `localFileURL`/`isDownloaded` (transient, excluded from `CodingKeys`), all
  `CodingKeys` (upstream has none), the thumbnail URL helpers extension.
- `formattedDuration` is inlined in the extension (upstream keeps it as a global
  `formatDuration` in `TimeFormatting.swift`, which doesn't exist in Unwatched).

**`InnerTubeModels.swift`:** `PlayerInfo` carries an extra `originalAudioLanguage: String`
field not in upstream — preserve it in the struct and in `applyingPoToken(_:)`. `APIError` also
carries the Unwatched-only `ageRestricted` case (alongside `ipBlocked`/`scheduled`) — preserve it
and its `errorDescription`.

**`InnerTubeAPI+Networking.swift`:** `seedVisionOSSession` sends the `SOCS=CAI` consent cookie as a
`Cookie` header instead of writing it to `HTTPCookieStorage.shared`. `InnerTubeAPI`'s session has no
cookie store (see its `init`), so upstream's cookie would never be sent, and `.shared` is the iOS
web view's cookie file.

**`InnerTubeAPI+Player.swift`:** keep `import NaturalLanguage` and the
`originalAudioLanguage` detection block inside `parsePlayerInfo` (uses
`NLLanguageRecognizer` on title+description). Keep `ITVideo(` constructor calls. Keep the
age-gate branch in `parsePlayerInfo`'s unplayable block, which throws `APIError.ageRestricted`
*before* the `signInRequired` check: an age gate is definitive on every unauthenticated client,
whereas "sign in to confirm you're not a bot" is per-client and must stay `signInRequired` so the
retry loop keeps going.

---

## How to upgrade

1. `cd ../SmartTubeIOS && git pull`
2. List what changed in each mirrored file since the last sync, skipping the format commit, e.g.:
   ```
   git log --oneline <last-synced>..HEAD -- SmartTubeIOS/Sources/SmartTubeIOSCore/<file>.swift
   git diff -w <last-synced> HEAD -- <path>   # or per commit: git show <sha> -- <path>
   ```
   Most upstream commits are app-only (UI, widgets, TestFlight builds); only the mirrored paths
   matter. Client version bumps in `InnerTubeClients.swift` are the most valuable part.
3. Apply upstream changes, then re-apply the adaptations above. Patches made from pre-format
   commits mostly apply with `patch` after `sed 's/package /public /'`; hunks touching
   comments Unwatched trimmed need placing by hand.
4. Work through *After a sync* below.
5. Bump **Last synced commit** in this file.

---

## Playback orchestration (`AVPlayerViewModel+Loading.swift`)

`fetchAndPlay` mirrors the *attempt loop* of upstream `PlaybackViewModel.exhaustiveRetry`
(the bottom half) — not the top-half Phase -1a/-2/-1b race,
which depends on `VideoPreloadCache`/`BotGuardWebViewRunner` (not mirrored). Flow:

1. **Fast path** — cached WKWebView HLS URL (`WKHLSManager.validEntry`).
2. **`primaryRace`** — iOS client fetch with a WKWebView extraction started alongside it;
   lightweight stand-in for upstream's BotGuard race, no extra infrastructure needed.
   iOS HLS plays immediately and cancels the extraction. If iOS has no HLS the extraction
   is *not* waited for (it takes seconds to tens of seconds) — playback falls through to
   `exhaustiveRetry` and `cacheWebViewExtractionWhenDone` caches the late URL and, while
   still on the 360p muxed fallback, swaps it in via `swapInWebViewHLS`.
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
  **`APIError.ageRestricted`** (see `verdict(_:)`) is recorded but does *not* cancel the group —
  TVEmbedded and AndroidVR can still serve an age gate — and is only acted on once every client
  has come back empty.
- **`+Fallback.swift`** holds what happens then: `handleScheduledVideo`, and `failPlayback`
  for every terminal failure (age gate, IP block, exhausted retries, unrecoverable item error),
  which hands off to the YouTube page instead of showing the error when the native player is
  only standing in for a failed embed (foreground only).
- **`handleItemFailure`** routes mid-playback `.failed` through
  **`qualityRecoveryAction`** (403/quality-cap/H.264 decode → re-`exhaustiveRetry`;
  else surface the error).

Keep this attempt-loop structurally aligned with upstream so a `diff` still maps.
Don't pull upstream's race/cache helpers without mirroring their infrastructure.

## After a sync

The view models (`AVPlayerViewModel*.swift`) consume the Core layer. Check for:

1. New `APIError` cases in `InnerTubeModels.swift` → classify in `verdict(_:)` (`+Loading`), act on in `+Fallback`.
2. New `PlayerInfo` fields → expose in the player if user-facing.
3. New `InnerTubeAPI` methods that improve reliability/quality, e.g.
   `fetchPlayerInfoAndroidVR` (audio-only, no PO token) or
   `fetchPlayerInfoForDownload` (muxed MP4, future download feature).
4. Quality switching — `rebuildCompositionForQuality` uses `VideoFormat.url` from
   `PlayerInfo.formats` directly; mirror upstream if format filtering/sorting changes.
5. Watch history — the tracking API exists but isn't wired up; see `WatchtimeTracker` above.

---

## Key design constraints

- **`AVMutableComposition` vs HLS**: `preferredMaximumResolution` is silently ignored
  on composition items — always branch on `isUsingComposition` for quality changes.
- **VP9 exclusion**: filter `vp09` from every quality list/composition URL picker —
  causes decode failures on some Apple hardware.
- **`package` keyword**: never use it — write `public` instead (see the global adaptation above).
- **Module boundary**: `Core/` cannot see app types. Anything it would need from the app belongs
  in `UnwatchedShared` (as `ChannelAvatarService` already is), and app-side extensions of
  `InnerTubeAPI` can only touch its `public` members.
- **NaturalLanguage**: `originalAudioLanguage` detection is Unwatched-only.
