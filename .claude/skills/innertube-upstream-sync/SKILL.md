---
name: innertube-upstream-sync
description: Sync Unwatched's InnerTube player layer (SmartTube/ and UnwatchedShared InnerTube/Core/) with upstream SmartTubeIOS, or change one of those mirrored files. Holds the last synced commit, the file map, every per-file adaptation to re-apply, and the post-sync checklist.
---

# InnerTube — upstream sync

`Unwatched/Unwatched/InnerTube/SmartTube/` and `UnwatchedShared/UnwatchedShared/InnerTube/Core/`
mirror SmartTubeIOS. Design goals and constraints for the layer are in
`Unwatched/Unwatched/InnerTube/CLAUDE.md`; this is the sync procedure.

## Upstream source

- **Repo:** `../SmartTubeIOS` (sibling checkout, alongside this repo)
- **Package paths** (inside that repo): `SmartTubeIOS/Sources/SmartTubeIOSCore/` for `Core/` and
  `AudioTrack`/`HLSAudioLanguageParser`; `SmartTubeIOS/Sources/SmartTubeIOS/Services/` for
  `YTHLSProxyLoader` and `YouTubeWebViewHLSExtractor`
- **Last synced commit:** `e659ce9` — update after every sync
- **Upstream is swift-formatted since `a1dbf49`**, Unwatched's copies are not, so a whole-file
  `diff` is mostly line-wrapping noise. Diff by commit instead (see *How to upgrade*).

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
| `InnerTubeAPI+Browse.swift`, `+VideoRenderers.swift` | `InnerTubeAPI+Search.swift` | **Not a mirror** — a trimmed port of the search/lockup parsers only (see its adaptations below). Pull renderer fixes by hand when they touch `videoRenderer`/`reelItemRenderer`/`lockupViewModel` parsing |

Not mirrored (app-level, not needed here): `BrowseViewModel`, `HomeViewModel`,
`SearchViewModel`, `PlaylistViewModel`, `DownloadStore`, `HLSManifestCache`,
`SponsorBlockService/SkipManager`, `iCloudSyncManager`, `LocalSubscription*`, `RSS*`,
`VideoPreloadCache`, etc.

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

**`InnerTubeAPI+Search.swift`** (a trimmed port of upstream's browse/renderer parsers):
`InnerTubeAPI+Search.swift`'s `parseSearchPage(from:)` is internal instead of `private`, so
`InnerTube/HomeFeed/` can parse the home feed and related videos with it. Those responses are
fetched from inside a hidden youtube.com web view (`HomeFeedService`), so a signed-in session
never leaves WebKit — see `YoutubeCookieFilter` for why the app's own requests can't carry it.
Re-apply the `private` → internal change on every sync.

`parseLockupViewModel` also reads the duration from the thumbnail badge
(`contentImage.thumbnailViewModel.overlays[].thumbnailBottomOverlayViewModel.badges[]`); upstream
passes `duration: nil` there, so lockup results (most home, related and many search results)
showed no length. Re-apply on every sync.

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

