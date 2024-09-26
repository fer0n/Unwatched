//
//  UrlService.swift
//  Unwatched
//

import Foundation
import OSLog
import UnwatchedShared

struct UrlService {
    static let youtubeStartPage = URL(string: "https://m.youtube.com?autoplay=0")
    static let youtubeStartPageString = "https://m.youtube.com?autoplay=0"

    static let shareShortcutUrl = URL(string: "https://www.icloud.com/shortcuts/08d23cfd38624043a00d626f9b5b00c6")
    static let youtubeTakeoutUrl = URL(string: "https://takeout.google.com/takeout/custom/youtube")!

    static let writeReviewUrl = URL(string: "https://apps.apple.com/app/id6477287463?action=write-review")!
    static let githubUrl = URL(string: "https://github.com/fer0n/Unwatched")!
    static let mastodonUrl = URL(string: "https://indieapps.space/@unwatched")!
    static let releasesUrl = URL(string: "https://github.com/fer0n/Unwatched/releases")!

    static func getEmailUrl(body: String) -> URL {
        URL(string: "mailto:unwatched.app@gmail.com?body=\n\n\(body)")!
    }

    static func getNonEmbeddedYoutubeUrl (_ youtubeId: String, _ startAt: Double) -> String {
        "https://www.youtube.com/watch?v=\(youtubeId)&t=\(startAt)s"
    }

    static func getEmbeddedYoutubeUrl (_ youtubeId: String, _ startAt: Double) -> String {
        let enableYtWatchHistory = (UserDefaults.standard.value(forKey: Const.enableYtWatchHistory) as? Bool) ?? true
        let cookieUrl = enableYtWatchHistory ? "" : "-nocookie"
        return  "https://www.youtube\(cookieUrl).com/embed/\(youtubeId)"
            + "?t=\(startAt)s&enablejsapi=1&color=white&controls=1&iv_load_policy=3"
    }

    static func stringContainsUrl (_ text: String) -> Bool {
        let regex = #"https:\/\/\w+\.\w+"#
        return text.matching(regex: regex) != nil
    }

    static func getYoutubeIdFromUrl(url: URL) -> String? {
        // https://www.youtube.com/watch?v=epBbbysk5cU
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let id = urlComponents?.queryItems?.first(where: { $0.name == "v" })?.value {
            return id
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

        // https://m.youtube.com/shorts/jH_QIBtX1gY
        // https://www.youtube.com/watch?v=epBbbysk5cU
        // https://piped.video/watch?v=VZIm_2MgdeA
        let regex = #"(?:https\:\/\/)?(?:www\.)?(?:m\.)?(?:\S+\.\S+\/(?:(?:watch\?v=)|(?:shorts\/))([^\s\/\?\n]+))"#
        let res = url.absoluteString.matching(regex: regex)
        return res
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
        let urlString = url.absoluteString

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

    static func getCleanTitle(_ title: String?) -> String? {
        if let title = title {
            return title.replacingOccurrences(of: " - YouTube", with: "")
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
        // swiftlint:disable:next line_length
        let regex = #"((?:https\:\/\/)?(?:www\.)?(?:m\.)?(youtube.com\/(?:(?:watch\?v=)|(?:shorts\/))[^\/\?\n]+|youtu.be\/[^\/\?\n]+))"#
        let matches = text.matchingMultiple(regex: regex)
        if let matches = matches {
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
        if let matches = matches {
            let urls = matches.compactMap { URL(string: $0) }
            let rest = text.replacingOccurrences(of: regex, with: "", options: .regularExpression)
            return (urls, rest)
        }
        return ([], text)
    }

    static func getYoutubeUrl(userName: String? = nil,
                              channelId: String? = nil,
                              playlistId: String? = nil,
                              mobile: Bool = true) -> String? {
        let baseUrl = "https://\(mobile ? "m." : "")youtube.com"
        if let playlistId = playlistId {
            return "\(baseUrl)/playlist?list=\(playlistId)"
        }
        if let userName = userName {
            return "\(baseUrl)/@\(userName)/videos"
        }
        if let channelId = channelId {
            return "\(baseUrl)/channel/\(channelId)/videos"
        }
        Logger.log.warning("nothing to create a url from")
        return nil
    }
}
