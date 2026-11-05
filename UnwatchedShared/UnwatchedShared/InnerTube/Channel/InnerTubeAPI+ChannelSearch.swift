//
//  InnerTubeAPI+ChannelSearch.swift
//  UnwatchedShared
//

import Foundation

extension InnerTubeAPI {
    public func searchChannels(query: String) async throws -> [YoutubeChannelSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }
        var body = makeBody(client: webClientContext)
        body["query"] = trimmed
        body["params"] = SearchFilter(type: .channel).encodedParams()
        let data = try await post(endpoint: "search", body: body)
        guard data["error"] == nil, data["contents"] != nil else {
            throw APIError.decodingError("channel search returned no contents")
        }
        let results = parseChannelSearchResults(from: data)
        Log.innerTube.notice("channel search → \(results.count) channels")
        return results
    }

    private func parseChannelSearchResults(from json: [String: Any]) -> [YoutubeChannelSearchResult] {
        var seen = Set<String>()
        return channelRenderers(in: json).compactMap { renderer in
            guard let channelId = renderer["channelId"] as? String,
                  let title = text(renderer["title"]),
                  seen.insert(channelId).inserted else {
                return nil
            }
            let handleOrCount = [text(renderer["subscriberCountText"]), text(renderer["videoCountText"])]
                .compactMap { $0 }
            return YoutubeChannelSearchResult(
                channelId: channelId,
                title: title,
                userName: handleOrCount.first(where: \.isHandle).map { String($0.dropFirst()) },
                subscriberCount: handleOrCount.first { !$0.isHandle },
                thumbnailUrl: thumbnailUrl(renderer["thumbnail"])
            )
        }
    }

    private func channelRenderers(in value: Any, depth: Int = 0) -> [[String: Any]] {
        guard depth < 30 else { return [] }
        if let dict = value as? [String: Any] {
            if let renderer = dict["channelRenderer"] as? [String: Any]
                ?? dict["compactChannelRenderer"] as? [String: Any] {
                return [renderer]
            }
            return dict.values.flatMap { channelRenderers(in: $0, depth: depth + 1) }
        }
        if let array = value as? [Any] {
            return array.flatMap { channelRenderers(in: $0, depth: depth + 1) }
        }
        return []
    }

    private func text(_ value: Any?) -> String? {
        guard let dict = value as? [String: Any],
              let text = extractText(dict),
              !text.isEmpty else {
            return nil
        }
        return text
    }

    private func thumbnailUrl(_ value: Any?) -> URL? {
        guard let thumbnails = (value as? [String: Any])?["thumbnails"] as? [[String: Any]],
              let url = thumbnails.last?["url"] as? String else {
            return nil
        }
        return URL(string: url.hasPrefix("//") ? "https:" + url : url)
    }
}

private extension String {
    var isHandle: Bool { hasPrefix("@") }
}
