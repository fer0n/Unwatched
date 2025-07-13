//
//  UrlService.swift
//  Unwatched
//

import Foundation
import OSLog
import UnwatchedShared
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct UrlService {
    static let youtubeStartPage = URL(staticString: "https://m.youtube.com?autoplay=0")
    static let youtubeStartPageString = "https://m.youtube.com?autoplay=0"

    static let shareShortcutUrl = URL(staticString: "https://www.icloud.com/shortcuts/08d23cfd38624043a00d626f9b5b00c6")
    static let youtubeTakeoutUrl = URL(staticString: "https://takeout.google.com/takeout/custom/youtube")

    static let writeReviewUrl = URL(staticString: "https://apps.apple.com/app/id6477287463?action=write-review")
    static let githubUrl = URL(staticString: "https://github.com/fer0n/Unwatched")
    static let mastodonUrl = URL(staticString: "https://indieapps.space/@unwatched")
    static let blueskyUrl = URL(staticString: "https://bsky.app/profile/unwatched.bsky.social")
    static let releasesUrl = URL(staticString: "https://github.com/fer0n/Unwatched/releases")

    static let issuesUrl = URL(staticString: "https://github.com/fer0n/Unwatched/issues")

    static func getShortenedUrl(_ youtubeId: String, timestamp: Double? = nil) -> String {
        "https://youtu.be/\(youtubeId)" + (timestamp.map { "?t=\(Int($0))" } ?? "")
    }

    static func getEmailUrl(title: String? = nil, body: String) -> URL {
        let subject = title != nil ? "subject=\(title ?? "")&" : ""
        return URL(string: "mailto:unwatched.app@gmail.com?\(subject)body=\n\n\(body)")!
    }

    static func getNonEmbeddedYoutubeUrl (_ youtubeId: String, _ startAt: Double? = nil) -> String {
        if let startAt {
            return "https://www.youtube.com/watch?v=\(youtubeId)&t=\(startAt)s"
        }
        return "https://www.youtube.com/watch?v=\(youtubeId)"
    }

    static func getEmbeddedYoutubeUrl (_ youtubeId: String, _ startAt: Double) -> String {
        let useNoCookieUrl = UserDefaults.standard.bool(forKey: Const.useNoCookieUrl)
        let cookieUrl = useNoCookieUrl ? "-nocookie" : ""
        let disableCaptions = UserDefaults.standard.bool(forKey: Const.disableCaptions)
        let captionsUrl = disableCaptions ? "&cc_load_policy=0" : ""
        return  "https://www.youtube\(cookieUrl).com/embed/\(youtubeId)"
            + "?t=\(startAt)s&enablejsapi=1&color=white&controls=1&iv_load_policy=3\(captionsUrl)"
    }

    static func getStartTimeFromUrl(_ url: URL) -> Double? {
        // https://www.youtube.com/watch?v=epBbbysk5cU&t=60s
        let regex = #"t=(\d+(\.\d+)?)"# // Match seconds with optional decimal part
        if let match = url.absoluteString.matching(regex: regex) {
            return Double(match)
        }
        return nil
    }

    static func addTimeToUrl(_ url: URL, time: Double) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var queryItems = components.queryItems ?? []
        if let index = queryItems.firstIndex(where: { $0.name == "t" }) {
            queryItems[index].value = "\(Int(time))s"
        } else {
            queryItems.append(URLQueryItem(name: "t", value: "\(Int(time))s"))
        }
        components.queryItems = queryItems
        return components.url
    }

    static func stringContainsUrl (_ text: String) -> Bool {
        let regex = #"https:\/\/\w+\.\w+"#
        return text.matching(regex: regex) != nil
    }

    static func getYoutubeIdFromUrl(url: URL) -> String? {
        // https://m.youtube.com/shorts/jH_QIBtX1gY
        // https://www.youtube.com/watch?v=epBbbysk5cU
        // https://piped.video/watch?v=VZIm_2MgdeA
        // https://m.youtube.com/watch?v=Sa-FI9exq8o&pp=ygUTRGV2aWwgR2VvcmdpYSBjb3Zlcg%3D%3D
        let regex = #"(?:https\:\/\/)?(?:www\.)?(?:m\.)?(?:\S+\.\S+\/(?:(?:watch\?v=)|(?:shorts\/))([^\s\/\?\&\n]+))"#
        if let res = url.absoluteString.matching(regex: regex) {
            return res
        }

        // https://youtu.be/dtp6b76pMak
        let shortRegex = #"(?:https\:\/\/)?(?:www\.)?youtu\.be\/([^\s\/\?\n]+)"#
        if let res = url.absoluteString.matching(regex: shortRegex) {
            return res
        }

        // https://www.youtube.com/embed/Udl16tb2xv8?t=1414.0486603120037s&enablejsapi=1
        let embedRegex = #"(?:https\:\/\/)?(?:www\.)?youtube\.com\/embed\/([^\s\/\?\n]+)"#
        if let res = url.absoluteString.matching(regex: embedRegex) {
            return res
        }

        // swiftlint:disable:next line_length
        // https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://www.youtube.com/watch%3Fv%3D1K5oDtVAYzk&ved=2ahUKEwjTwKmPx6SLAxUHTDABHQ0WDRsQwqsBegQIYxAG&usg=AOvVaw2wqHdPMbGG4kUgVDx4nR-w
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let encodedUrl = urlComponents?.queryItems?.first(where: { $0.name == "url" })?.value,
           let decodedUrl = encodedUrl.removingPercentEncoding,
           let actualUrl = URL(string: decodedUrl) {
            let urlComponents = URLComponents(url: actualUrl, resolvingAgainstBaseURL: false)
            if let id = urlComponents?.queryItems?.first(where: { $0.name == "v" })?.value {
                return id
            }
        }

        return nil
    }

    static func isYoutubeVideoUrl(url: URL) -> Bool {
        self.getYoutubeIdFromUrl(url: url) != nil
    }

    static func isYoutubeFeedUrl(url: URL) -> Bool {
        // https://www.youtube.com/feeds/videos.xml?user=GAMERTAGVR
        // https://www.youtube.com/feeds/videos.xml?channel_id=UCnrAvt4i_2WV3yEKWyEUMlg
        return url.absoluteString.contains("youtube.com/feeds/videos.xml")
    }

    static func getFeedUrlFromChannelId(_ channelId: String) throws -> URL {
        if let channelFeedUrl = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelId)") {
            return channelFeedUrl
        }
        throw SubscriptionError.notSupported
    }

    static func getChannelUserNameFromUrl(_ url: URL, previousUserName: String? = nil) -> String? {
        let urlString = url.absoluteString.removingPercentEncoding ?? url.absoluteString

        // https://www.youtube.com/@GAMERTAGVR/videos
        if let userName = urlString.matching(regex: #"\/@([^\/#\?]*)"#) {
            return userName
        }

        // https://www.youtube.com/c/GamertagVR/videos
        if let userName = urlString.matching(regex: #"\/c\/([^\/]*)"#) {
            return userName
        }

        // https://www.youtube.com/feeds/videos.xml?user=GAMERTAGVR
        if let userName = urlString.matching(regex: #"\/videos.xml\?user=(.*)"#) {
            return userName
        }

        // https://www.youtube.com/user/JPRPokeTrainer98
        if let userName = urlString.matching(regex: #"\/user\/([^\/#\?\s]*)"#) {
            return userName
        }

        // https://www.youtube.com/moviepilot
        // some channels forward to this kind of url (non-mobile), but the username is already known by then
        if let prev = previousUserName?.lowercased(), urlString.lowercased().contains("youtube.com/\(prev)") {
            return previousUserName
        }

        return nil
    }

    static func getChannelIdFromUrl(_ url: URL) -> String? {
        return getChannelIdFromUrl(url.absoluteString)
    }

    static func getChannelIdFromUrl(_ url: String) -> String? {
        // https://www.youtube.com/feeds/videos.xml?user=GAMERTAGVR
        if let channelId = url.matching(regex: #"\/channel\/([^\s\/\?\n#]+)"#) {
            return channelId
        }
        return nil
    }

    static func getPlaylistIdFromUrl(_ url: URL) -> String? {
        getPlaylistIdFromUrl(url.absoluteString)
    }

    static func getPlaylistIdFromUrl(_ url: String) -> String? {
        // https://www.youtube.com/feeds/videos.xml?playlist_id=PLKp8CenWaxrBvyoP7cq3ESrXhnS7yGaTh
        if let playlistId = url.matching(regex: #"\/videos\.xml\?playlist_id=([^\s\/\?\n#]+)"#) {
            return playlistId
        }
        // https://www.youtube.com/playlist?list=PL6BHqJ_7o92sPDB2UpgWBYdeyeSs-pc8_
        if let playlistId = url.matching(regex: #"\/playlist\?list=([^\s\/\?\n#]+)"#) {
            return playlistId
        }
        return nil
    }

    static func getPlaylistFeedUrl(_ playlistId: String) throws -> URL {
        if let channelFeedUrl = URL(string: "https://www.youtube.com/feeds/videos.xml?playlist_id=\(playlistId)") {
            return channelFeedUrl
        }
        throw SubscriptionError.notSupported
    }

    static func isMobileYoutubePage(_ url: URL) -> Bool {
        let urlString = url.absoluteString
        return urlString.contains("m.youtube.com")
    }

    static func extractVideoUrls(_ text: String) -> (videoUrls: [URL], rest: String) {
        // https://www.youtube.com/watch?v=epBbbysk5cU
        // https://www.m.youtube.com/watch?v=epBbbysk5cU
        // https://youtu.be/dtp6b76pMak
        // https://m.youtube.com/shorts/jH_QIBtX1gY
        // https://www.youtube.com/embed/QHpTxLM9opU

        // swiftlint:disable:next line_length
        let regex = #"((?:https\:\/\/)?(?:www\.)?(?:m\.)?(youtube.com\/(?:(?:watch\?v=)|(?:shorts\/)|(?:embed\/))[^\/\?\n\s]+|youtu.be\/[^\/\?\n]+))\??\S*"#
        let matches = text.matchingMultiple(regex: regex)
        if let matches {
            let urls = matches.compactMap { URL(string: $0) }
            let rest = text.replacingOccurrences(of: regex, with: "", options: .regularExpression)
            return (urls, rest)
        }
        return ([], text)
    }

    static func extractPlaylistUrls(_ text: String) -> (playlistUrls: [URL], rest: String) {
        // https://www.youtube.com/playlist?list=PL6BHqJ_7o92sPDB2UpgWBYdeyeSs-pc8_
        let regex = #"((?:https\:\/\/)?(?:www\.)?(?:m\.)?(youtube.com\/playlist\?list\=[^\/\?\s]+))"#
        let matches = text.matchingMultiple(regex: regex)
        if let matches {
            let urls = matches.compactMap { URL(string: $0) }
            let rest = text.replacingOccurrences(of: regex, with: "", options: .regularExpression)
            return (urls, rest)
        }
        return ([], text)
    }

    static func getYoutubeUrl(userName: String? = nil,
                              channelId: String? = nil,
                              playlistId: String? = nil,
                              mobile: Bool = true,
                              videosSubPath: Bool = true) -> String? {
        let baseUrl = "https://\(mobile ? "m." : "")youtube.com"
        if let playlistId {
            return "\(baseUrl)/playlist?list=\(playlistId)"
        }
        let subPath = videosSubPath ? "/videos" : ""
        if let userName {
            return "\(baseUrl)/@\(userName)\(subPath)"
        }
        if let channelId {
            return "\(baseUrl)/channel/\(channelId)\(subPath)"
        }
        Log.warning("nothing to create a url from")
        return nil
    }

    @MainActor
    static func open(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}
