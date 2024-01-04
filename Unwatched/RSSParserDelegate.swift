//
//  RSSParserDelegate.swift
//  Unwatched
//

import Foundation


class RSSParserDelegate: NSObject, XMLParserDelegate {
    var videos: [Video] = []
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

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "link" && attributeDict["rel"] == "alternate" {
            currentLink = attributeDict["href"] ?? ""
        } else if elementName == "media:thumbnail" {
            thumbnailUrl = attributeDict["url"] ?? ""
        }
    }


    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title": currentTitle += string
        case "yt:videoId": currentYoutubeId += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "entry" {
            if let url = URL(string: currentLink), let thumbnailUrl = URL(string: thumbnailUrl) {
                print("url", url)
                print("thumbnailUrl", thumbnailUrl)
                let video = Video(title: currentTitle, url: url, youtubeId: currentYoutubeId, thumbnailUrl: thumbnailUrl)
                videos.append(video)
            } else {
                print("couldn't create the video")
            }
            currentTitle = ""
            currentLink = ""
            thumbnailUrl = ""
            currentYoutubeId = ""
        }
    }
}
