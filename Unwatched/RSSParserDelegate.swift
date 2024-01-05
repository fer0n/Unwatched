//
//  RSSParserDelegate.swift
//  Unwatched
//

import Foundation

class RSSParserDelegate: NSObject, XMLParserDelegate {
    var videos: [Video] = []
    var subscriptionInfo: Subscription?
    var limitVideos: Int?
    var cutoffDate: Date?

    var currentElement = ""
    var currentTitle: String = "" {
        didSet {
            currentTitle = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    var currentLink: String = "" {
        didSet {
            currentLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    var thumbnailUrl: String = "" {
        didSet {
            thumbnailUrl = thumbnailUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    var currentYoutubeId: String = "" {
        didSet {
            currentYoutubeId = currentYoutubeId.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    var currentPublishedDate: String = "" {
        didSet {
            currentPublishedDate = currentPublishedDate.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    init(limitVideos: Int?, cutoffDate: Date?) {
        self.limitVideos = limitVideos
        self.cutoffDate = cutoffDate
    }

    override init() { }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName

        if elementName == "link" && attributeDict["rel"] == "alternate" {
            currentLink = attributeDict["href"] ?? ""
        } else if elementName == "media:thumbnail" {
            thumbnailUrl = attributeDict["url"] ?? ""
        } else if elementName == "entry",
                  subscriptionInfo == nil,
                  let url = URL(string: currentLink) {
            // TODO: find a better way to retrieve the info.
            // it currently only works if the channel info comes before the first entry
            subscriptionInfo = Subscription(link: url, title: currentTitle)
            currentTitle = ""
            currentLink = ""
            thumbnailUrl = ""
            currentYoutubeId = ""
            currentPublishedDate = ""
            // TODO: why the += ? better way to load all this?
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title": currentTitle += string
        case "yt:videoId": currentYoutubeId += string
        case "published": currentPublishedDate += string
        default: break
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "entry" {
            let dateFormatter = ISO8601DateFormatter()
            if let publishedDate = dateFormatter.date(from: currentPublishedDate),
               let url = URL(string: currentLink),
               let thumbnailUrl = URL(string: thumbnailUrl) {
                let video = Video(title: currentTitle,
                                  url: url, youtubeId: currentYoutubeId,
                                  thumbnailUrl: thumbnailUrl,
                                  publishedDate: publishedDate)

                if (limitVideos != nil && videos.count >= limitVideos!) ||
                    cutoffDate != nil && publishedDate <= cutoffDate! {
                    parser.abortParsing()
                    return
                }
                videos.append(video)
            } else {
                print("couldn't create the video")
            }
            currentTitle = ""
            currentLink = ""
            thumbnailUrl = ""
            currentYoutubeId = ""
            currentPublishedDate = ""
        }
    }
}
