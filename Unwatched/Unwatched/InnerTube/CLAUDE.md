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
- If an upstream file needs a small change, document it in the diff table in the
  `innertube-upstream-sync` skill and in a comment at the change site.

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

## Upstream sync

`SmartTube/` and `Core/` mirror SmartTubeIOS (`../SmartTubeIOS`). **Before syncing, or before
changing a mirrored file, load the `innertube-upstream-sync` skill** — it has the last synced
commit, the upstream-vs-Unwatched file map and diff tables, every per-file adaptation, and the
post-sync checklist. The adaptations that most often get lost in an edit:

- `package` is always `public` here — `Core/` is its own module and the app reads it across the
  boundary.
- `ITVideo`/`ITChapter`, never `Video`/`Chapter` (SwiftData name conflicts).
- Unwatched-only additions to preserve: `PlayerInfo.originalAudioLanguage` and its
  `NaturalLanguage` detection, `APIError.ageRestricted` and its check before `signInRequired`,
  the `SOCS=CAI` cookie as a header, internal `parseSearchPage`, lockup durations.

---

## Project notes

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

---

## Key design constraints

- **`AVMutableComposition` vs HLS**: `preferredMaximumResolution` is silently ignored
  on composition items — always branch on `isUsingComposition` for quality changes.
- **VP9 exclusion**: filter `vp09` from every quality list/composition URL picker —
  causes decode failures on some Apple hardware.
- **`package` keyword**: never use it — write `public` instead (see *Upstream sync* above).
- **Module boundary**: `Core/` cannot see app types. Anything it would need from the app belongs
  in `UnwatchedShared` (as `ChannelAvatarService` already is), and app-side extensions of
  `InnerTubeAPI` can only touch its `public` members.
- **NaturalLanguage**: `originalAudioLanguage` detection is Unwatched-only.
