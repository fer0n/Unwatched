//
//  InnerTubeAPI+LiveStreams.swift
//  UnwatchedShared
//

import Foundation
import OSLog

private let log = Logger(subsystem: appSubsystem, category: "InnerTubeLiveStreams")

extension InnerTubeAPI {
    /// Upcoming, running and past live streams, but not premieres.
    public func fetchChannelLiveStreamIds(channelId: String) async throws -> Set<String> {
        var body = makeBody(client: webClientContext)
        body["browseId"] = channelId
        body["params"] = "EgdzdHJlYW1z8gYECgJ6AA=="
        let data = try await post(endpoint: "browse", body: body)
        let ids = parseVideoLockupIds(from: data)
        log.notice("channel \(channelId, privacy: .public) live streams → \(ids.count, privacy: .public)")
        return ids
    }

    private func parseVideoLockupIds(from json: [String: Any]) -> Set<String> {
        var ids = Set<String>()

        func walk(_ obj: Any, _ depth: Int) {
            guard depth < 30 else { return }
            if let dict = obj as? [String: Any] {
                if let lockup = dict["lockupViewModel"] as? [String: Any],
                   (lockup["contentType"] as? String) == "LOCKUP_CONTENT_TYPE_VIDEO",
                   let videoId = lockup["contentId"] as? String {
                    ids.insert(videoId)
                    return
                }
                for value in dict.values { walk(value, depth + 1) }
            } else if let arr = obj as? [Any] {
                for item in arr { walk(item, depth + 1) }
            }
        }

        walk(json, 0)
        return ids
    }
}
