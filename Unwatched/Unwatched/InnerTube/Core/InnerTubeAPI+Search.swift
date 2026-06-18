import Foundation
import os

private let tubeLog = Logger(subsystem: appSubsystem, category: "InnerTubeSearch")

// MARK: - YouTube search (InnerTube WEB client)
//
// Ported from SmartTubeIOSCore (InnerTubeAPI+Browse.swift / InnerTubeAPI+VideoRenderers.swift),
// trimmed to the renderers a WEB `search` response actually returns. Reuses the existing
// `post`, `makeBody`, `webClientContext` networking primitives and the `extractText` /
// `parseDuration` / `extractNumber` / `parseRelativeDate` text helpers already in Core.

extension InnerTubeAPI {

    struct SearchPage: Sendable {
        var videos: [ITVideo]
        var nextPageToken: String?
    }

    /// A playlist published by a channel (from the channel's Playlists tab).
    struct ITPlaylist: Sendable, Identifiable, Hashable {
        var id: String          // playlistId (e.g. "PL…")
        var title: String
        var thumbnailURL: URL?
        var videoCountText: String?   // e.g. "12 videos" / "5 episodes"
    }

    /// Run a search (or fetch the next page when `continuationToken` is set).
    /// Impersonates the desktop WEB client — no auth, no PO token required.
    func search(
        query: String,
        continuationToken: String? = nil,
        filter: SearchFilter = .default
    ) async throws -> SearchPage {
        var body = makeBody(client: webClientContext, continuationToken: continuationToken)
        if continuationToken == nil {
            body["query"] = query
            if let params = filter.encodedParams() {
                body["params"] = params
            }
        }
        let data = try await post(endpoint: "search", body: body)
        let page = parseSearchPage(from: data)
        tubeLog.notice("search '\(query, privacy: .public)' → \(page.videos.count, privacy: .public) videos, nextPage=\(page.nextPageToken != nil ? "yes" : "no", privacy: .public)")
        return page
    }

    /// YouTube autocomplete suggestions (public, key-less endpoint).
    func fetchSearchSuggestions(query: String) async throws -> [String] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty,
              var components = URLComponents(string: "https://suggestqueries-clients6.youtube.com/complete/search") else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "client", value: "youtube"),
            URLQueryItem(name: "ds", value: "yt"),
            URLQueryItem(name: "q", value: query),
        ]
        guard let url = components.url else { return [] }
        let (data, _) = try await session.data(from: url)
        guard let raw = String(data: data, encoding: .utf8),
              let arrayStart = raw.firstIndex(of: "["),
              let arrayEnd = raw.lastIndex(of: "]") else {
            return []
        }
        let jsonString = String(raw[arrayStart...arrayEnd])
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [Any],
              let suggestions = json[safe: 1] as? [[Any]] else {
            return []
        }
        return suggestions.compactMap { $0[safe: 0] as? String }
    }

    /// Fetches a channel's avatar URL via a lightweight `browse` request for the
    /// channel's About tab (`params = EgVhYm91dA==` → header only, no video grid).
    /// Mirrors SmartTubeIOS `fetchChannelThumbnailURL`. Returns nil on failure.
    func fetchChannelAvatarURL(channelId: String) async throws -> URL? {
        var body = makeBody(client: webClientContext)
        body["browseId"] = channelId
        body["params"] = "EgVhYm91dA=="
        let data = try await post(endpoint: "browse", body: body)

        let headerDict = data["header"] as? [String: Any]
        let header = (headerDict?["c4TabbedHeaderRenderer"] as? [String: Any])
            ?? (headerDict?["pageHeaderRenderer"] as? [String: Any])

        // c4TabbedHeaderRenderer.avatar.thumbnails[-1]
        if let urlStr = ((header?["avatar"] as? [String: Any])?["thumbnails"] as? [[String: Any]])?
            .last?["url"] as? String {
            return URL(string: urlStr)
        }
        // pageHeaderViewModel: content.pageHeaderViewModel.image.decoratedAvatarViewModel
        //   .avatar.avatarViewModel.image.sources[-1]
        if let hvm = (header?["content"] as? [String: Any])?["pageHeaderViewModel"] as? [String: Any],
           let image = ((((hvm["image"] as? [String: Any])?["decoratedAvatarViewModel"] as? [String: Any])?["avatar"] as? [String: Any])?["avatarViewModel"] as? [String: Any])?["image"] as? [String: Any],
           let urlStr = (image["sources"] as? [[String: Any]])?.last?["url"] as? String {
            return URL(string: urlStr)
        }
        // metadata fallback: metadata.channelMetadataRenderer.avatar.thumbnails[-1]
        if let urlStr = (((data["metadata"] as? [String: Any])?["channelMetadataRenderer"] as? [String: Any])?["avatar"] as? [String: Any])
            .flatMap({ ($0["thumbnails"] as? [[String: Any]])?.last?["url"] as? String }) {
            return URL(string: urlStr)
        }
        return nil
    }

    /// Fetches the playlists a channel publishes (its "Playlists" tab) via `browse`.
    /// `params` is the protobuf-encoded tab selector for the Playlists tab. Returns the
    /// playlists in the channel's own ordering; empty on failure or if the channel has none.
    func fetchChannelPlaylists(channelId: String) async throws -> [ITPlaylist] {
        var body = makeBody(client: webClientContext)
        body["browseId"] = channelId
        body["params"] = "EglwbGF5bGlzdHPyBgQKAkIA"
        let data = try await post(endpoint: "browse", body: body)
        let playlists = parseChannelPlaylists(from: data)
        tubeLog.notice("channel \(channelId, privacy: .public) playlists → \(playlists.count, privacy: .public)")
        return playlists
    }

    /// Walks the channel Playlists-tab response, collecting playlist `lockupViewModel`s.
    private func parseChannelPlaylists(from json: [String: Any]) -> [ITPlaylist] {
        var result: [ITPlaylist] = []
        var seen = Set<String>()

        func walk(_ obj: Any, _ depth: Int) {
            guard depth < 30 else { return }
            if let dict = obj as? [String: Any] {
                if let lockup = dict["lockupViewModel"] as? [String: Any],
                   (lockup["contentType"] as? String) == "LOCKUP_CONTENT_TYPE_PLAYLIST",
                   let playlist = parsePlaylistLockup(lockup), !seen.contains(playlist.id) {
                    seen.insert(playlist.id)
                    result.append(playlist)
                    return
                }
                for value in dict.values { walk(value, depth + 1) }
            } else if let arr = obj as? [Any] {
                for item in arr { walk(item, depth + 1) }
            }
        }

        walk(json, 0)
        return result
    }

    /// Parses a single playlist `lockupViewModel` (id, title, thumbnail, item-count badge).
    private func parsePlaylistLockup(_ lockup: [String: Any]) -> ITPlaylist? {
        guard let playlistId = lockup["contentId"] as? String, !playlistId.isEmpty else { return nil }

        let meta = (lockup["metadata"] as? [String: Any])?["lockupMetadataViewModel"] as? [String: Any]
        let title = ((meta?["title"] as? [String: Any])?["content"] as? String) ?? ""

        // First image source anywhere in contentImage (handles both the single
        // `thumbnailViewModel` and the stacked `collectionThumbnailViewModel`).
        let thumbURL = (lockup["contentImage"] as? [String: Any])
            .flatMap { firstThumbnailURL(in: $0) }

        // First badge text that contains a digit ("12 videos" / "5 episodes").
        let countText = (lockup["contentImage"] as? [String: Any]).flatMap { firstCountBadgeText(in: $0) }

        return ITPlaylist(id: playlistId, title: title, thumbnailURL: thumbURL, videoCountText: countText)
    }

    /// Depth-first search for the last (highest-res) URL in the first `image.sources` array.
    private func firstThumbnailURL(in object: Any) -> URL? {
        if let dict = object as? [String: Any] {
            if let image = dict["image"] as? [String: Any],
               let sources = image["sources"] as? [[String: Any]],
               let urlStr = sources.last?["url"] as? String {
                return URL(string: urlStr)
            }
            for value in dict.values {
                if let found = firstThumbnailURL(in: value) { return found }
            }
        } else if let array = object as? [Any] {
            for item in array {
                if let found = firstThumbnailURL(in: item) { return found }
            }
        }
        return nil
    }

    /// Depth-first search for the first `thumbnailBadgeViewModel.text` containing a digit.
    private func firstCountBadgeText(in object: Any) -> String? {
        if let dict = object as? [String: Any] {
            if let badge = dict["thumbnailBadgeViewModel"] as? [String: Any],
               let text = badge["text"] as? String,
               text.contains(where: \.isNumber) {
                return text
            }
            for value in dict.values {
                if let found = firstCountBadgeText(in: value) { return found }
            }
        } else if let array = object as? [Any] {
            for item in array {
                if let found = firstCountBadgeText(in: item) { return found }
            }
        }
        return nil
    }

    // MARK: - Response walking

    /// Recursively walks the search-response JSON, collecting videos from every known
    /// renderer type and the pagination continuation token. Works for both the first
    /// page (twoColumnSearchResultsRenderer → sectionListRenderer) and continuation
    /// pages (onResponseReceivedCommands → appendContinuationItemsAction).
    private func parseSearchPage(from json: [String: Any]) -> SearchPage {
        var videos: [ITVideo] = []
        var seen = Set<String>()
        var nextPageToken: String?

        func append(_ video: ITVideo?) {
            guard let video, !seen.contains(video.id) else { return }
            seen.insert(video.id)
            videos.append(video)
        }

        func walk(_ obj: Any, _ depth: Int) {
            guard depth < 30 else { return }
            if let dict = obj as? [String: Any] {
                if let r = dict["videoRenderer"] as? [String: Any] {
                    append(parseVideoRenderer(r)); return
                }
                if let r = dict["reelItemRenderer"] as? [String: Any] {
                    append(parseReelItemRenderer(r)); return
                }
                if let r = dict["shortsLockupViewModel"] as? [String: Any] {
                    append(parseShortsLockupViewModel(r)); return
                }
                if let r = dict["compactVideoRenderer"] as? [String: Any] {
                    append(parseVideoRenderer(r)); return
                }
                if let r = dict["lockupViewModel"] as? [String: Any] {
                    append(parseLockupViewModel(r)); return
                }
                if let contItem = dict["continuationItemRenderer"] as? [String: Any],
                   let endpoint = contItem["continuationEndpoint"] as? [String: Any],
                   let command = endpoint["continuationCommand"] as? [String: Any],
                   let token = command["token"] as? String {
                    nextPageToken = token
                    return
                }
                for value in dict.values { walk(value, depth + 1) }
            } else if let arr = obj as? [Any] {
                for item in arr { walk(item, depth + 1) }
            }
        }

        walk(json, 0)
        return SearchPage(videos: videos, nextPageToken: nextPageToken)
    }

    /// Depth-first search for the first `browseEndpoint.browseId` that looks like a channel
    /// ID (`UC…`). Used to pull the primary channel out of a collaboration byline's chooser
    /// dialog when the run itself has no direct channel `browseEndpoint`.
    private func firstChannelBrowseId(in object: Any) -> String? {
        if let dict = object as? [String: Any] {
            if let browseId = (dict["browseEndpoint"] as? [String: Any])?["browseId"] as? String,
               browseId.hasPrefix("UC") {
                return browseId
            }
            for value in dict.values {
                if let found = firstChannelBrowseId(in: value) { return found }
            }
        } else if let array = object as? [Any] {
            for item in array {
                if let found = firstChannelBrowseId(in: item) { return found }
            }
        }
        return nil
    }

    // MARK: - Renderer parsers

    /// WEB videoRenderer / gridVideoRenderer / compactVideoRenderer parser.
    private func parseVideoRenderer(_ r: [String: Any]) -> ITVideo? {
        guard let videoId = r["videoId"] as? String else { return nil }
        let title = (r["title"] as? [String: Any]).flatMap { extractText($0) }
            ?? (r["headline"] as? [String: Any]).flatMap { extractText($0) }
            ?? ""
        let channelTitle = (r["ownerText"] as? [String: Any]).flatMap { extractText($0) }
            ?? (r["shortBylineText"] as? [String: Any]).flatMap { extractText($0) }
            ?? ""

        let channelId: String? = {
            let sourceKey = r["ownerText"] != nil ? "ownerText" : "shortBylineText"
            guard let runs = (r[sourceKey] as? [String: Any])?["runs"] as? [[String: Any]],
                  let first = runs.first,
                  let nav = first["navigationEndpoint"] as? [String: Any]
            else { return nil }
            if let browseId = (nav["browseEndpoint"] as? [String: Any])?["browseId"] as? String {
                return browseId
            }
            // Collaboration videos have a multi-channel byline whose navigationEndpoint is a
            // `showDialogCommand` (a collaborators chooser) instead of a `browseEndpoint`.
            // Fall back to the first listed channel so the video still links to a channel.
            return firstChannelBrowseId(in: nav)
        }()

        let thumbnails = (r["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
        let thumbURL = thumbnails?.last.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }

        let lengthText: String? = (r["lengthText"] as? [String: Any]).flatMap { extractText($0) }
            ?? (r["thumbnailOverlays"] as? [[String: Any]])?
                .compactMap { ($0["thumbnailOverlayTimeStatusRenderer"] as? [String: Any])?["text"] as? [String: Any] }
                .first.flatMap { extractText($0) }
        let duration = lengthText.flatMap { parseDuration($0) }

        let viewCountText = (r["viewCountText"] as? [String: Any]).flatMap { extractText($0) }
            ?? (r["shortViewCountText"] as? [String: Any]).flatMap { extractText($0) }
        let viewCount = viewCountText.flatMap { extractNumber($0) } ?? r["viewCount"] as? Int

        let isLive = (r["badges"] as? [[String: Any]])?.contains {
            (($0["metadataBadgeRenderer"] as? [String: Any])?["style"] as? String) == "BADGE_STYLE_TYPE_LIVE_NOW"
        } ?? false

        let isShort: Bool = {
            if let nav = r["navigationEndpoint"] as? [String: Any], nav["reelWatchEndpoint"] != nil {
                if duration.map({ $0 <= 180 }) ?? true { return true }
            }
            let hasShortOverlay = (r["thumbnailOverlays"] as? [[String: Any]])?.contains {
                ($0["thumbnailOverlayTimeStatusRenderer"] as? [String: Any])?["style"] as? String == "SHORTS"
            } ?? false
            if hasShortOverlay && (duration.map { $0 <= 180 } ?? true) { return true }
            let isVerticalThumbnail = thumbnails?.contains {
                let w = ($0["width"] as? Int) ?? 0
                let h = ($0["height"] as? Int) ?? 0
                return h > w && w > 0
            } ?? false
            return isVerticalThumbnail && (duration.map { $0 <= 180 } ?? true)
        }()

        let badges = (r["badges"] as? [[String: Any]])?.compactMap {
            ($0["metadataBadgeRenderer"] as? [String: Any])?["label"] as? String
        } ?? []

        let publishedTimeText: String? = (r["publishedTimeText"] as? [String: Any]).flatMap { extractText($0) }
        let publishedAt: Date? = publishedTimeText.flatMap { parseRelativeDate($0) }

        return ITVideo(
            id: videoId,
            title: title,
            channelTitle: channelTitle,
            channelId: channelId,
            thumbnailURL: thumbURL,
            duration: duration,
            viewCount: viewCount,
            publishedAt: publishedAt,
            publishedTimeText: publishedTimeText,
            isLive: isLive,
            isShort: isShort,
            badges: badges
        )
    }

    /// Shorts reelItemRenderer parser.
    private func parseReelItemRenderer(_ r: [String: Any]) -> ITVideo? {
        guard let videoId = r["videoId"] as? String else { return nil }
        let title = (r["headline"] as? [String: Any]).flatMap { extractText($0) } ?? ""
        let thumbnails = (r["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
        let thumbURL = thumbnails?.last.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }

        let channelTitle: String = (r["ownerText"] as? [String: Any]).flatMap { extractText($0) }
            ?? (r["shortBylineText"] as? [String: Any]).flatMap { extractText($0) }
            ?? ""

        let channelId: String? = {
            if let channelId = (r["navigationEndpoint"] as? [String: Any])
                .flatMap({ ($0["reelWatchEndpoint"] as? [String: Any])?["channelId"] as? String }) {
                return channelId
            }
            let sourceKey = r["ownerText"] != nil ? "ownerText" : "shortBylineText"
            guard let runs = (r[sourceKey] as? [String: Any])?["runs"] as? [[String: Any]],
                  let first = runs.first,
                  let nav = first["navigationEndpoint"] as? [String: Any],
                  let browse = nav["browseEndpoint"] as? [String: Any]
            else { return nil }
            return browse["browseId"] as? String
        }()

        let viewCount: Int? = (r["viewCountText"] as? [String: Any])
            .flatMap { extractText($0) }
            .flatMap { extractNumber($0) }

        return ITVideo(
            id: videoId,
            title: title,
            channelTitle: channelTitle,
            channelId: channelId,
            thumbnailURL: thumbURL,
            viewCount: viewCount,
            isShort: true,
            hasPortraitThumbnail: true
        )
    }

    /// WEB search Shorts (reelShelfRenderer → items[] → shortsLockupViewModel).
    private func parseShortsLockupViewModel(_ r: [String: Any]) -> ITVideo? {
        guard let onTap = r["onTap"] as? [String: Any],
              let command = onTap["innertubeCommand"] as? [String: Any],
              let reelEp = command["reelWatchEndpoint"] as? [String: Any],
              let videoId = reelEp["videoId"] as? String,
              !videoId.isEmpty
        else { return nil }

        let title: String = {
            guard let overlay = r["overlayMetadata"] as? [String: Any],
                  let primary = overlay["primaryText"] as? [String: Any],
                  let content = primary["content"] as? String
            else { return "" }
            return content
        }()

        let viewCount: Int? = {
            guard let overlay = r["overlayMetadata"] as? [String: Any],
                  let secondary = overlay["secondaryText"] as? [String: Any],
                  let content = secondary["content"] as? String
            else { return nil }
            return extractNumber(content)
        }()

        let thumbURL: URL? = {
            if let thumbDict = reelEp["thumbnail"] as? [String: Any],
               let thumbs = thumbDict["thumbnails"] as? [[String: Any]],
               let urlStr = thumbs.last?["url"] as? String {
                return URL(string: urlStr)
            }
            if let tvm = r["thumbnailViewModel"] as? [String: Any],
               let image = tvm["image"] as? [String: Any],
               let sources = image["sources"] as? [[String: Any]],
               let urlStr = sources.last?["url"] as? String {
                return URL(string: urlStr)
            }
            return nil
        }()

        return ITVideo(
            id: videoId,
            title: title,
            channelTitle: "",
            thumbnailURL: thumbURL,
            viewCount: viewCount,
            isShort: true
        )
    }

    /// WEB v2 lockupViewModel parser. Returns nil for non-video lockups (channels/playlists),
    /// which conveniently filters them out of a video-only search.
    private func parseLockupViewModel(_ lockup: [String: Any]) -> ITVideo? {
        guard let rendererContext = lockup["rendererContext"] as? [String: Any],
              let commandContext = rendererContext["commandContext"] as? [String: Any],
              let onTap = commandContext["onTap"] as? [String: Any],
              let innertubeCommand = onTap["innertubeCommand"] as? [String: Any] else { return nil }

        let reelEndpoint = innertubeCommand["reelWatchEndpoint"] as? [String: Any]
        let watchEndpoint = innertubeCommand["watchEndpoint"] as? [String: Any]
        guard let videoId = reelEndpoint?["videoId"] as? String
                          ?? watchEndpoint?["videoId"] as? String else { return nil }
        let isShort = reelEndpoint != nil

        let lockupMeta = (lockup["metadata"] as? [String: Any])?["lockupMetadataViewModel"] as? [String: Any]
        let title: String = {
            guard let titleDict = lockupMeta?["title"] as? [String: Any] else { return "" }
            return titleDict["content"] as? String ?? extractText(titleDict) ?? ""
        }()

        let metaContentVM = (lockupMeta?["metadata"] as? [String: Any])?["contentMetadataViewModel"] as? [String: Any]
        let metaRows = metaContentVM?["metadataRows"] as? [[String: Any]] ?? []

        let channelTitle: String = {
            guard let firstRow = metaRows.first,
                  let parts = firstRow["metadataParts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? [String: Any]
            else { return "" }
            return text["content"] as? String ?? extractText(text) ?? ""
        }()

        let channelId: String? = (watchEndpoint?["channelId"] as? String)
                               ?? (reelEndpoint?["channelId"] as? String) ?? {
            for row in metaRows {
                guard let parts = row["metadataParts"] as? [[String: Any]] else { continue }
                for part in parts {
                    guard let text = part["text"] as? [String: Any],
                          let commandRuns = text["commandRuns"] as? [[String: Any]]
                    else { continue }
                    for run in commandRuns {
                        guard let cmd = (run["onTap"] as? [String: Any])?["innertubeCommand"] as? [String: Any],
                              let browseId = (cmd["browseEndpoint"] as? [String: Any])?["browseId"] as? String,
                              browseId.hasPrefix("UC")
                        else { continue }
                        return browseId
                    }
                }
            }
            return nil
        }()

        let thumbVM = (lockup["contentImage"] as? [String: Any])?["thumbnailViewModel"] as? [String: Any]
        let thumbnails = (thumbVM?["image"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
        let thumbURL = thumbnails?.last.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }

        let publishedAt: Date? = {
            for row in metaRows.dropFirst() {
                guard let parts = row["metadataParts"] as? [[String: Any]] else { continue }
                for part in parts {
                    guard let text = part["text"] as? [String: Any],
                          let str = text["content"] as? String ?? extractText(text)
                    else { continue }
                    if let date = parseRelativeDate(str) { return date }
                }
            }
            return nil
        }()

        let viewCount: Int? = {
            for row in metaRows.dropFirst() {
                guard let parts = row["metadataParts"] as? [[String: Any]] else { continue }
                for part in parts {
                    guard let text = part["text"] as? [String: Any],
                          let str = text["content"] as? String ?? extractText(text)
                    else { continue }
                    if let count = extractNumber(str) { return count }
                }
            }
            return nil
        }()

        return ITVideo(
            id: videoId,
            title: title,
            channelTitle: channelTitle,
            channelId: channelId,
            thumbnailURL: thumbURL,
            viewCount: viewCount,
            publishedAt: publishedAt,
            isShort: isShort
        )
    }
}
