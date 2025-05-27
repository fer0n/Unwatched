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
    var currentTitle: String = ""
    var currentLink: String = ""
    var thumbnailUrl: String = ""
    var currentYoutubeId: String = ""
    var currentPublishedDate: String = ""
    var currentUpdatedDate: String = ""
    var currentDescription: String = ""
    var currentUri: String = ""
    var currentAuthor: String = ""

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
            let url = URL(string: currentLink.trimmingCharacters(in: .whitespacesAndNewlines))
            let channelId = getChannelIdFromAuthorUri(currentUri.trimmingCharacters(in: .whitespacesAndNewlines))
            subscriptionInfo = SendableSubscription(
                link: url,
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                author: currentAuthor.trimmingCharacters(in: .whitespacesAndNewlines),
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

            if let publishedDate = try? Date(
                currentPublishedDate.trimmingCharacters(in: .whitespacesAndNewlines),
                strategy: .iso8601
            ),
            let updatedDate =  try? Date(
                currentUpdatedDate.trimmingCharacters(in: .whitespacesAndNewlines),
                strategy: .iso8601
            ),
            let url = URL(string: currentLink.trimmingCharacters(in: .whitespacesAndNewlines)),
            let thumbnailUrl = URL(string: thumbnailUrl.trimmingCharacters(in: .whitespacesAndNewlines)) {
                let description = currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                let chapters = ChapterService.extractChapters(from: description, videoDuration: nil)

                let video = SendableVideo(youtubeId: currentYoutubeId.trimmingCharacters(in: .whitespacesAndNewlines),
                                          title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                          url: url,
                                          thumbnailUrl: thumbnailUrl,
                                          chapters: chapters,
                                          publishedDate: publishedDate,
                                          updatedDate: updatedDate,
                                          videoDescription: description)

                if limitVideos != nil && videos.count >= limitVideos! {
                    let channelId = getChannelIdFromAuthorUri(
                        currentUri.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    subscriptionInfo?.youtubeChannelId = channelId
                    parser.abortParsing()
                    return
                }
                videos.append(video)
            } else {
                Log.warning("couldn't create the video")
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
