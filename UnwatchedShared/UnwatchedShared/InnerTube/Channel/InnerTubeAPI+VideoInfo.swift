//
//  InnerTubeAPI+VideoInfo.swift
//  UnwatchedShared
//

import Foundation

extension InnerTubeAPI {
    /// WEB client: the iOS response has no `microformat`. Nil without a title, channel or date.
    public func fetchVideoInfo(videoId: String) async throws -> SendableVideo? {
        var body = makeBody(client: webClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await post(endpoint: "player", body: body)
        let microformat = (data["microformat"] as? [String: Any])?["playerMicroformatRenderer"] as? [String: Any]
        guard let details = data["videoDetails"] as? [String: Any],
              let title = details["title"] as? String, !title.isEmpty,
              let channelId = details["channelId"] as? String, !channelId.isEmpty,
              let publishedDate = Self.date(microformat?["publishDate"]) ?? Self.date(microformat?["uploadDate"]) else {
            return nil
        }
        let liveDetails = microformat?["liveBroadcastDetails"] as? [String: Any]
        let isLiveOrUpcoming = liveDetails?["isLiveNow"] as? Bool == true
            || details["isUpcoming"] as? Bool == true
        // Rounds like the Data API
        let roundedLength = (microformat?["lengthSeconds"] ?? details["lengthSeconds"]) as? String
        let duration = isLiveOrUpcoming ? nil : roundedLength.flatMap(Double.init).flatMap { $0 > 0 ? $0 : nil }

        return SendableVideo(
            youtubeId: videoId,
            title: title,
            url: YoutubeUrlParser.watchUrl(youtubeId: videoId),
            thumbnailUrl: URL(string: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"),
            youtubeChannelId: channelId,
            feedTitle: details["author"] as? String,
            duration: duration,
            publishedDate: publishedDate,
            videoDescription: details["shortDescription"] as? String
        )
    }

    private static func date(_ value: Any?) -> Date? {
        (value as? String).flatMap { try? Date($0, strategy: .iso8601) }
    }
}
