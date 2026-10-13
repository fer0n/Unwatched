//
//  InnerTubeAPI+PublishInfo.swift
//  UnwatchedShared
//

import Foundation

extension InnerTubeAPI {
    public struct PublishInfo: Sendable {
        public var publishedDate: Date
        public var description: String?
    }

    /// WEB client: the iOS response has no `microformat`.
    public func fetchPublishInfo(videoId: String) async throws -> PublishInfo? {
        var body = makeBody(client: webClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await post(endpoint: "player", body: body)
        let microformat = (data["microformat"] as? [String: Any])?["playerMicroformatRenderer"] as? [String: Any]
        guard let text = microformat?["publishDate"] as? String,
              let date = ISO8601DateFormatter().date(from: text) else {
            return nil
        }
        let description = (data["videoDetails"] as? [String: Any])?["shortDescription"] as? String
        return PublishInfo(publishedDate: date, description: description)
    }
}
