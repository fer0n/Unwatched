//
//  InnerTubeAPI+ChannelVideos.swift
//  UnwatchedShared
//

import Foundation
import OSLog

private let log = Logger(subsystem: appSubsystem, category: "InnerTubeChannelVideos")

extension InnerTubeAPI {
    public func fetchChannelVideos(channelId: String, continuationToken: String? = nil) async throws -> SearchPage {
        let data = try await browse(browseId: channelId, params: "EgZ2aWRlb3PyBgQKAjoA", continuationToken: continuationToken)
        let items = (tabContents(in: data, renderer: "richGridRenderer") ?? continuationItems(in: data)).map {
            (($0["richItemRenderer"] as? [String: Any])?["content"] as? [String: Any]) ?? $0
        }
        return lockupPage(items, channelId: channelId, logName: "channel \(channelId)")
    }

    public func fetchPlaylistVideos(playlistId: String, continuationToken: String? = nil) async throws -> SearchPage {
        let data = try await browse(browseId: "VL\(playlistId)", continuationToken: continuationToken)
        // a short playlist's suggestions continue in a section of their own
        let items = tabContents(in: data, renderer: "sectionListRenderer")?.lazy.compactMap {
            ($0["itemSectionRenderer"] as? [String: Any])?["contents"] as? [[String: Any]]
        }.first
        return lockupPage(items ?? continuationItems(in: data), channelId: nil, logName: "playlist \(playlistId)")
    }

    private func browse(browseId: String, params: String? = nil, continuationToken: String?) async throws -> [String: Any] {
        var body = makeBody(client: webClientContext, continuationToken: continuationToken)
        if continuationToken == nil {
            body["browseId"] = browseId
            body["params"] = params
        }
        return try await post(endpoint: "browse", body: body)
    }

    private func tabContents(in json: [String: Any], renderer: String) -> [[String: Any]]? {
        let browse = (json["contents"] as? [String: Any])?["twoColumnBrowseResultsRenderer"] as? [String: Any]
        let tabs = browse?["tabs"] as? [[String: Any]] ?? []
        return tabs.lazy.compactMap {
            let content = ($0["tabRenderer"] as? [String: Any])?["content"] as? [String: Any]
            return (content?[renderer] as? [String: Any])?["contents"] as? [[String: Any]]
        }.first
    }

    private func continuationItems(in json: [String: Any]) -> [[String: Any]] {
        let actions = json["onResponseReceivedActions"] as? [[String: Any]] ?? []
        return actions.lazy.compactMap {
            ($0["appendContinuationItemsAction"] as? [String: Any])?["continuationItems"] as? [[String: Any]]
        }.first ?? []
    }

    private func lockupPage(_ items: [[String: Any]], channelId: String?, logName: String) -> SearchPage {
        var videos: [ITVideo] = []
        var nextPageToken: String?
        for item in items {
            if let lockup = item["lockupViewModel"] as? [String: Any],
               let video = parseListLockup(lockup, channelId: channelId) {
                videos.append(video)
            } else if let token = continuationToken(of: item) {
                nextPageToken = token
            }
        }
        log.notice("\(logName, privacy: .public) videos → \(videos.count, privacy: .public), nextPage=\(nextPageToken != nil ? "yes" : "no", privacy: .public)")
        return SearchPage(videos: videos, nextPageToken: nextPageToken)
    }

    private func continuationToken(of item: [String: Any]) -> String? {
        let endpoint = (item["continuationItemRenderer"] as? [String: Any])?["continuationEndpoint"] as? [String: Any]
        return (endpoint?["continuationCommand"] as? [String: Any])?["token"] as? String
    }

    private func parseListLockup(_ lockup: [String: Any], channelId: String?) -> ITVideo? {
        guard (lockup["contentType"] as? String) == "LOCKUP_CONTENT_TYPE_VIDEO",
              let videoId = lockup["contentId"] as? String else { return nil }

        let meta = (lockup["metadata"] as? [String: Any])?["lockupMetadataViewModel"] as? [String: Any]
        let title = (meta?["title"] as? [String: Any])?["content"] as? String ?? ""
        let rows = ((meta?["metadata"] as? [String: Any])?["contentMetadataViewModel"] as? [String: Any])?["metadataRows"] as? [[String: Any]] ?? []
        let parts = rows.flatMap { $0["metadataParts"] as? [[String: Any]] ?? [] }
            .compactMap { $0["text"] as? [String: Any] }
        let published = parts.lazy
            .compactMap { $0["content"] as? String }
            .compactMap { text in self.parseRelativeDate(text).map { (text: text, date: $0) } }
            .first
        let byline = channelId == nil ? parts.lazy.compactMap(channelByline).first : nil

        let overlays = ((lockup["contentImage"] as? [String: Any])?["thumbnailViewModel"] as? [String: Any])?["overlays"] as? [[String: Any]] ?? []
        let badges = overlays.flatMap {
            ($0["thumbnailBottomOverlayViewModel"] as? [String: Any])?["badges"] as? [[String: Any]] ?? []
        }
        let duration = badges.lazy
            .compactMap { ($0["thumbnailBadgeViewModel"] as? [String: Any])?["text"] as? String }
            .compactMap { self.parseDuration($0) }
            .first

        return ITVideo(
            id: videoId,
            title: title,
            channelTitle: byline?.title ?? "",
            channelId: channelId ?? byline?.id,
            duration: duration,
            publishedAt: published?.date,
            publishedTimeText: published?.text
        )
    }

    private func channelByline(_ part: [String: Any]) -> (id: String, title: String)? {
        let runs = part["commandRuns"] as? [[String: Any]] ?? []
        let channelId = runs.lazy.compactMap {
            let command = ($0["onTap"] as? [String: Any])?["innertubeCommand"] as? [String: Any]
            return (command?["browseEndpoint"] as? [String: Any])?["browseId"] as? String
        }.first { $0.hasPrefix("UC") }
        guard let channelId else { return nil }
        return (channelId, part["content"] as? String ?? "")
    }
}
