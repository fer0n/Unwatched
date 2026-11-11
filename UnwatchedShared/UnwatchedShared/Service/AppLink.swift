//
//  AppLink.swift
//  UnwatchedShared
//

import Foundation

public enum AppLink {
    public static let host = "u.octabits.net"
    public static let hosts: Set<String> = [host, "unwatched.octabits.net"]

    public static func isAppLink(_ url: URL) -> Bool {
        url.host.map(hosts.contains) ?? false
    }

    public static func resolving(_ url: URL) -> URL {
        isAppLink(url) ? target(of: url) ?? url : url
    }

    public static func target(of url: URL) -> URL? {
        guard isAppLink(url) || url.scheme == "unwatched",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let value = { (name: String) in components.queryItems?.first { $0.name == name }?.value }
        let path = isAppLink(url) ? Array(url.pathComponents.dropFirst()) : []
        switch path.first {
        case "v":
            guard path.count == 2 else { return nil }
            return youtubeUrl(path[1], start: value("t"))
        case "p":
            guard path.count == 3, isNumeric(path[1]), isNumeric(path[2]) else { return nil }
            return applePodcastsUrl(show: path[1], episode: path[2], storefront: value("c"))
                .map { addingStart(value(ShareMarkers.startKey), to: $0) }
        case nil, "open", "play", "queue", "inbox":
            if let link = value("url").flatMap(URL.init(string:)) {
                let link = reattachingStrayFragment(components.fragment, to: link)
                return YoutubeUrlParser.getYoutubeId(from: link) == nil ? addingStart(value(ShareMarkers.startKey), to: link) : link
            }
            return value("v").flatMap { youtubeUrl($0, start: value("t")) }
        default:
            return nil
        }
    }

    private static func youtubeUrl(_ id: String, start: String?) -> URL? {
        guard id.count == 11, id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") })
        else { return nil }
        return YoutubeUrlParser.watchUrl(youtubeId: id, start: start.flatMap(UInt.init))
    }

    private static func applePodcastsUrl(show: String, episode: String, storefront: String?) -> URL? {
        let store = storefront?.lowercased()
        let hasStore = store.map { $0.count == 2 && $0.allSatisfy { $0.isASCII && $0.isLetter } } ?? false
        var components = URLComponents()
        components.scheme = "https"
        components.host = "podcasts.apple.com"
        components.path = (hasStore ? "/\(store ?? "")" : "") + "/podcast/id\(show)"
        components.queryItems = [URLQueryItem(name: "i", value: episode)]
        return components.url
    }

    private static func isNumeric(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy { $0.isASCII && $0.isNumber }
    }

    private static func addingStart(_ start: String?, to link: URL) -> URL {
        guard let seconds = start.flatMap(UInt.init) else { return link }
        return ShareMarkers.adding(ShareMarkers.startKey, String(seconds), to: link)
    }

    private static func reattachingStrayFragment(_ fragment: String?, to link: URL) -> URL {
        guard link.fragment == nil, let fragment,
              var components = URLComponents(url: link, resolvingAgainstBaseURL: false) else { return link }
        components.fragment = fragment
        return components.url ?? link
    }
}
