//
//  SubscribedChannelsParser.swift
//  UnwatchedShared
//

import Foundation

enum SubscribedChannelsParser {
    struct Page: Sendable {
        var channels: [SendableSubscription]
        var nextPageToken: String?
    }

    enum ParseError: Error {
        case invalidJson
    }

    static func parse(_ text: String) throws -> Page {
        guard let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) else {
            throw ParseError.invalidJson
        }
        var page = Page(channels: [], nextPageToken: nil)
        walk(json, into: &page)
        return page
    }

    private static func walk(_ node: Any, into page: inout Page) {
        if let array = node as? [Any] {
            for item in array { walk(item, into: &page) }
            return
        }
        guard let dict = node as? [String: Any] else { return }
        for (key, value) in dict {
            switch key {
            case "channelRenderer", "gridChannelRenderer":
                if let renderer = value as? [String: Any], let channel = channel(from: renderer) {
                    page.channels.append(channel)
                }
            case "continuationItemRenderer":
                if page.nextPageToken == nil {
                    page.nextPageToken = continuationToken(in: value)
                }
            default:
                walk(value, into: &page)
            }
        }
    }

    private static func continuationToken(in node: Any) -> String? {
        if let array = node as? [Any] {
            return array.lazy.compactMap(continuationToken(in:)).first
        }
        guard let dict = node as? [String: Any] else { return nil }
        if let command = dict["continuationCommand"] as? [String: Any], let token = command["token"] as? String {
            return token
        }
        return dict.values.lazy.compactMap(continuationToken(in:)).first
    }

    private static func channel(from renderer: [String: Any]) -> SendableSubscription? {
        guard let channelId = renderer["channelId"] as? String,
              let title = text(renderer["title"]), !title.isEmpty else {
            return nil
        }
        return SendableSubscription(
            title: title,
            youtubeChannelId: channelId,
            youtubeUserName: handle(renderer),
            thumbnailUrl: thumbnailUrl(renderer["thumbnail"])
        )
    }

    /// The channel link (`/@handle`), else the subscriber count text, which YouTube fills with the handle
    private static func handle(_ renderer: [String: Any]) -> String? {
        let navigation = renderer["navigationEndpoint"] as? [String: Any]
        let browse = navigation?["browseEndpoint"] as? [String: Any]
        let candidates = [
            (browse?["canonicalBaseUrl"] as? String).map { String($0.drop { $0 == "/" }) },
            text(renderer["subscriberCountText"])
        ]
        return candidates
            .compactMap { $0?.removingPercentEncoding }
            .first { $0.hasPrefix("@") && $0.count > 1 && !$0.contains(" ") }
            .map { String($0.dropFirst()) }
    }

    private static func text(_ node: Any?) -> String? {
        guard let dict = node as? [String: Any] else { return nil }
        if let simple = dict["simpleText"] as? String { return simple }
        if let runs = dict["runs"] as? [[String: Any]] {
            return runs.compactMap { $0["text"] as? String }.joined()
        }
        return nil
    }

    private static func thumbnailUrl(_ node: Any?) -> URL? {
        guard let dict = node as? [String: Any],
              let thumbnails = dict["thumbnails"] as? [[String: Any]],
              var url = thumbnails.last?["url"] as? String else {
            return nil
        }
        if url.hasPrefix("//") { url = "https:" + url }
        return URL(string: url)
    }
}
