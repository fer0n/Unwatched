//
//  UrlService.swift
//  Unwatched
//

import Foundation

struct UrlService {
    static let youtubeStartPage = URL(string: "https://m.youtube.com?autoplay=0")

    // TODO: fix links once it's been open/submitted
    static let shareShortcutUrl = URL(string: "https://www.icloud.com/shortcuts/08d23cfd38624043a00d626f9b5b00c6")
    static let writeReviewUrl = URL(string: "https://apps.apple.com/app/id6444704240?action=write-review")!
    static let emailUrl = URL(string: "mailto:scores.templates@gmail.com")!
    static let githubUrl = URL(string: "https://github.com/fer0n/SplitBill")!
    static let youtubeTakeoutUrl = URL(string: "https://takeout.google.com/takeout/custom/youtube")

    static func getEmbeddedYoutubeUrl (_ youtubeId: String) -> String {
        "https://www.youtube.com/embed/\(youtubeId)?enablejsapi=1&controls=1&color=white"
    }

    static func getNonEmbeddedYoutubeUrl (_ youtubeId: String, _ startAt: Double) -> String {
        "https://www.youtube.com/watch?v=\(youtubeId)&t=\(startAt)s"
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

        // https://m.youtube.com/shorts/jH_QIBtX1gY
        // https://www.youtube.com/watch?v=epBbbysk5cU
        let regex = #"(?:https\:\/\/)?(?:www\.)?(?:m\.)?(?:youtube.com\/(?:(?:watch\?v=)|(?:shorts\/))([^\s\/\?\n]+))"#
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

    static func getChannelUserNameFromUrl(url: URL, previousUserName: String? = nil) -> String? {
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

        // https://www.youtube.com/moviepilot
        // some channels forward to this kind of url (non-mobile), but the username is already known by then
        if let prev = previousUserName, urlString.contains("youtube.com/\(prev)") {
            print("previousUserName!!", prev)
            return previousUserName
        }

        return nil
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
        let regex = #"((?:https\:\/\/)?(?:www\.)?(?:m\.)?(youtube.com\/(?:(?:watch\?v=)|(?:shorts\/))[^\/\?\n]+|youtu.be\/[^\/\?\n]+))"#
        let matches = text.matchingMultiple(regex: regex)
        if let matches = matches {
            let urls = matches.compactMap { URL(string: $0) }
            let rest = text.replacingOccurrences(of: regex, with: "", options: .regularExpression)
            return (urls, rest)
        }
        return ([], text)
    }
}
