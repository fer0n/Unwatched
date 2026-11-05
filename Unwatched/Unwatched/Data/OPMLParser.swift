//
//  OPMLParser.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

class OPMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var result = [SendableSubscription]()

    init(data: Data) {
        self.data = data
    }

    nonisolated static func subscriptions(in file: URL) throws -> [SendableSubscription] {
        let isSecureAccess = file.startAccessingSecurityScopedResource()
        defer {
            if isSecureAccess {
                file.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: file)
        return OPMLParser(data: data).parse().sorted { $0.title < $1.title }
    }

    func parse() -> [SendableSubscription] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return result
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        guard elementName == "outline",
              let xmlUrl = attributes["xmlUrl"],
              let components = URLComponents(string: xmlUrl) else {
            return
        }
        let title = attributes["title"] ?? attributes["text"]
        if let channelId = components.queryItems?.first(where: { $0.name == "channel_id" })?.value {
            result.append(SendableSubscription(title: title ?? channelId, youtubeChannelId: channelId))
        } else if let feedUrl = components.url {
            result.append(SendableSubscription(link: feedUrl, title: title ?? xmlUrl, isPodcast: true))
        }
    }
}
