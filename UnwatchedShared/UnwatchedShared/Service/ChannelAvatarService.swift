//
//  ChannelAvatarService.swift
//  UnwatchedShared
//

import Foundation

/// Fetches a channel's avatar URL via YouTube's InnerTube `browse` endpoint (About tab only, no
/// video grid). Lives here rather than in the main app's InnerTube layer (the more natural home)
/// because the Share Extension needs this same fetch but can't import InnerTube — too much
/// video-playback-specific dependency surface for what should stay a lightweight extension. The
/// main app's `InnerTubeAPI.fetchChannelAvatarURL`
/// (`Unwatched/InnerTube/Core/InnerTubeAPI+Search.swift`) just calls into this, so there's a
/// single implementation instead of two copies that could drift. If the embedded WEB client
/// version ever starts failing, this is the only place to update it.
public enum ChannelAvatarService {
    private static let baseURL = URL(string: "https://www.youtube.com/youtubei/v1")!
    // Public InnerTube API key embedded in YouTube's own web client JS — not a developer secret.
    // nosec: false positive — this key is published by Google in youtube.com/s/player JS.
    private static let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8" // gitleaks:allow
    private static let webClientVersion = "2.20260206.01.00"

    public static func fetchAvatarURL(channelId: String) async throws -> URL? {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("browse"), resolvingAgainstBaseURL: false) else {
            return nil
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("1", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(webClientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "context": [
                "client": [
                    "hl": "en",
                    "gl": "US",
                    "clientName": "WEB",
                    "clientVersion": webClientVersion
                ]
            ],
            "browseId": channelId,
            "params": "EgVhYm91dA=="
        ])

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return avatarURL(from: json)
    }

    private static func avatarURL(from json: [String: Any]) -> URL? {
        let headerDict = json["header"] as? [String: Any]
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
        if let urlStr = (((json["metadata"] as? [String: Any])?["channelMetadataRenderer"] as? [String: Any])?["avatar"] as? [String: Any])
            .flatMap({ ($0["thumbnails"] as? [[String: Any]])?.last?["url"] as? String }) {
            return URL(string: urlStr)
        }
        return nil
    }
}
