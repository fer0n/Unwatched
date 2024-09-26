//
//  RSSParserDelegate.swift
//  Unwatched
//

import Foundation
import OSLog
import UnwatchedShared

class RSSParserDelegate: NSObject, XMLParserDelegate {
    var videos: [SendableVideo] = []
    var subscriptionInfo: SendableSubscription?
    var limitVideos: Int?

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
    var currentUpdatedDate: String = "" {
        didSet {
            currentUpdatedDate = currentUpdatedDate.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    var currentDescription: String = ""
    var currentUri: String = "" {
        didSet {
            currentUri = currentUri.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    var currentAuthor: String = "" {
        didSet {
            currentAuthor = currentAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    init(limitVideos: Int?) {
        self.limitVideos = limitVideos
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
                  subscriptionInfo == nil {
            let url = URL(string: currentLink)
            let channelId = getChannelIdFromAuthorUri(currentUri)
            subscriptionInfo = SendableSubscription(
                link: url,
                title: currentTitle,
                author: currentAuthor,
                youtubeChannelId: channelId)
            currentTitle = ""
            currentLink = ""
            thumbnailUrl = ""
            currentYoutubeId = ""
            currentPublishedDate = ""
            currentUpdatedDate = ""
            currentUri = ""
            currentAuthor = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title": currentTitle += string
        case "yt:videoId": currentYoutubeId += string
        case "published": currentPublishedDate += string
        case "updated": currentUpdatedDate += string
        case "media:description": currentDescription += string
        case "uri": currentUri += string
        case "name": currentAuthor += string
        default: break
        }
    }

    func getChannelIdFromAuthorUri(_ uri: String) -> String? {
        UrlService.getChannelIdFromUrl(uri)
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "entry" {

            if let publishedDate = try? Date(currentPublishedDate, strategy: .iso8601),
               let updatedDate =  try? Date(currentUpdatedDate, strategy: .iso8601),
               let url = URL(string: currentLink),
               let thumbnailUrl = URL(string: thumbnailUrl) {
                let chapters = ChapterService.extractChapters(from: currentDescription, videoDuration: nil)

                let video = SendableVideo(youtubeId: currentYoutubeId,
                                          title: currentTitle,
                                          url: url,
                                          thumbnailUrl: thumbnailUrl,
                                          chapters: chapters,
                                          publishedDate: publishedDate,
                                          updatedDate: updatedDate,
                                          videoDescription: currentDescription)

                if limitVideos != nil && videos.count >= limitVideos! {
                    let channelId = getChannelIdFromAuthorUri(currentUri)
                    subscriptionInfo?.youtubeChannelId = channelId
                    parser.abortParsing()
                    return
                }
                videos.append(video)
            } else {
                Logger.log.warning("couldn't create the video")
            }
            currentTitle = ""
            currentLink = ""
            thumbnailUrl = ""
            currentYoutubeId = ""
            currentPublishedDate = ""
            currentUpdatedDate = ""
            currentDescription = ""
            currentUri = ""
            currentAuthor = ""
        }
    }
}
