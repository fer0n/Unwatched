//
//  YoutubeUrlParser.swift
//  UnwatchedShared
//
//  Pure YouTube URL parsing, shared between the app (UrlService) and the share extension.
//  Self-contained so it carries no dependencies beyond Foundation.
//

import Foundation

public enum YoutubeUrlParser {

    /// Extracts the video id from a watch / shorts / youtu.be / embed / live URL
    /// (and from Google redirect URLs that wrap one).
    public static func getYoutubeId(from url: URL) -> String? {
        let string = url.absoluteString

        // https://m.youtube.com/shorts/jH_QIBtX1gY
        // https://www.youtube.com/watch?v=epBbbysk5cU
        // https://www.youtube.com/watch/?v=epBbbysk5cU
        // https://piped.video/watch?v=VZIm_2MgdeA
        // https://m.youtube.com/watch?v=Sa-FI9exq8o&pp=ygUTRGV2aWwgR2VvcmdpYSBjb3Zlcg%3D%3D
        let regex
            = #"(?:https\:\/\/)?(?:www\.)?(?:m\.)?(?:\S+\.\S+\/(?:(?:watch\/?\?v=)|(?:shorts\/))([^\s\/\?\&\n]+))"#
        if let res = firstCapture(in: string, regex: regex) {
            return res
        }

        // https://youtu.be/dtp6b76pMak
        let shortRegex = #"(?:https\:\/\/)?(?:www\.)?youtu\.be\/([^\s\/\?\n]+)"#
        if let res = firstCapture(in: string, regex: shortRegex) {
            return res
        }

        // https://www.youtube.com/live/l6p4bWw_oEk?t=1h54m11s
        // https://www.youtube.com/embed/Udl16tb2xv8?t=1414.0486603120037s&enablejsapi=1
        let embedOrLiveRegex = #"(?:https:\/\/)?(?:www\.)?youtube\.com\/(?:live|embed)\/([^\s\/\?\n]+)"#
        if let res = firstCapture(in: string, regex: embedOrLiveRegex) {
            return res
        }

        // Google redirect: ...&url=https://www.youtube.com/watch%3Fv%3D1K5oDtVAYzk&...
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let encodedUrl = components?.queryItems?.first(where: { $0.name == "url" })?.value,
           let decodedUrl = encodedUrl.removingPercentEncoding,
           let actualUrl = URL(string: decodedUrl) {
            let inner = URLComponents(url: actualUrl, resolvingAgainstBaseURL: false)
            if let id = inner?.queryItems?.first(where: { $0.name == "v" })?.value {
                return id
            }
        }

        return nil
    }

    public static func getPlaylistId(from url: URL) -> String? {
        getPlaylistId(from: url.absoluteString)
    }

    public static func getPlaylistId(from urlString: String) -> String? {
        // https://www.youtube.com/feeds/videos.xml?playlist_id=PLKp8CenWaxrBvyoP7cq3ESrXhnS7yGaTh
        if let playlistId = firstCapture(in: urlString, regex: #"\/videos\.xml\?playlist_id=([^\s\/\?\n#]+)"#) {
            return playlistId
        }
        // https://www.youtube.com/playlist?list=PL6BHqJ_7o92sPDB2UpgWBYdeyeSs-pc8_
        if let playlistId = firstCapture(in: urlString, regex: #"\/playlist\?list=([^\s\/\?\n#]+)"#) {
            return playlistId
        }
        return nil
    }

    /// https://www.youtube.com/shorts/rCllEeHXjUw
    public static func isShort(_ url: URL) -> Bool {
        url.absoluteString.contains("/shorts/")
    }

    /// True if the URL points at a YouTube video, short, live, embed, or playlist.
    public static func isContentUrl(_ url: URL) -> Bool {
        getYoutubeId(from: url) != nil || getPlaylistId(from: url) != nil
    }

    /// True if the URL points at a channel or user page (not a video/playlist).
    public static func isChannelUrl(_ url: URL) -> Bool {
        !isContentUrl(url)
            && (getChannelId(from: url) != nil || getChannelUserName(from: url) != nil || isFeedUrl(url))
    }

    public static func getStartTime(from url: URL) -> Double? {
        // https://www.youtube.com/watch?v=epBbbysk5cU&t=60s
        let regex = #"t=(\d+(\.\d+)?)"#
        guard let match = firstCapture(in: url.absoluteString, regex: regex), !match.isEmpty else {
            return nil
        }
        return Double(match)
    }

    /// https://www.youtube.com/feeds/videos.xml?user=GAMERTAGVR
    /// https://www.youtube.com/feeds/videos.xml?channel_id=UCnrAvt4i_2WV3yEKWyEUMlg
    public static func isFeedUrl(_ url: URL) -> Bool {
        url.absoluteString.contains("youtube.com/feeds/videos.xml")
    }

    public static func getFeedUrl(fromChannelId channelId: String) throws -> URL {
        if let channelFeedUrl = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelId)") {
            return channelFeedUrl
        }
        throw SubscriptionError.notSupported
    }

    public static func getFeedUrl(fromPlaylistId playlistId: String) throws -> URL {
        if let channelFeedUrl = URL(string: "https://www.youtube.com/feeds/videos.xml?playlist_id=\(playlistId)") {
            return channelFeedUrl
        }
        throw SubscriptionError.notSupported
    }

    public static func getChannelId(from url: URL) -> String? {
        // https://www.youtube.com/feeds/videos.xml?user=GAMERTAGVR
        firstCapture(in: url.absoluteString, regex: #"\/channel\/([^\s\/\?\n#]+)"#)
    }

    public static func getChannelUserName(from url: URL) -> String? {
        let urlString = url.absoluteString.removingPercentEncoding ?? url.absoluteString

        // https://www.youtube.com/@GAMERTAGVR/videos
        if let userName = firstCapture(in: urlString, regex: #"\/@([^\/#\?]*)"#), !userName.isEmpty {
            return userName
        }

        // https://www.youtube.com/c/GamertagVR/videos
        if let userName = firstCapture(in: urlString, regex: #"\/c\/([^\/]*)"#), !userName.isEmpty {
            return userName
        }

        // https://www.youtube.com/feeds/videos.xml?user=GAMERTAGVR
        if let userName = firstCapture(in: urlString, regex: #"\/videos.xml\?user=(.*)"#), !userName.isEmpty {
            return userName
        }

        // https://www.youtube.com/user/JPRPokeTrainer98
        if let userName = firstCapture(in: urlString, regex: #"\/user\/([^\/#\?\s]*)"#), !userName.isEmpty {
            return userName
        }

        return nil
    }

    public static func getChannelId(fromAuthorUri uri: String) -> String? {
        firstCapture(in: uri, regex: #"\/channel\/([^\s\/\?\n#]+)"#)
    }

    /// Returns the first capture group of `regex` in `string`, an empty string if it matched
    /// without a capture group, or nil if there was no match. (Mirrors `String.matching(regex:)`.)
    private static func firstCapture(in string: String, regex: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: regex) else { return nil }
        let range = NSRange(location: 0, length: string.utf16.count)
        guard let match = expression.firstMatch(in: string, options: [], range: range) else { return nil }
        if match.numberOfRanges > 1, let captureRange = Range(match.range(at: 1), in: string) {
            return String(string[captureRange])
        }
        return ""
    }
}
