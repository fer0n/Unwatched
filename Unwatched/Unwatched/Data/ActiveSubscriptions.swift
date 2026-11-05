//
//  ActiveSubscriptions.swift
//  Unwatched
//

import Foundation
import SwiftData
import UnwatchedShared

struct ActiveSubscriptions {
    private var channelIds = Set<String>()
    private var feedKeys = Set<String>()

    init() { }

    init(_ modelContext: ModelContext) {
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate { $0.isArchived == false })
        let subscriptions = (try? modelContext.fetch(fetch)) ?? []
        channelIds = Set(subscriptions.filter { $0.youtubePlaylistId == nil }.compactMap(\.youtubeChannelId))
        feedKeys = Set(subscriptions.filter(\.isPodcast).compactMap(\.link).map(Self.feedKey))
    }

    func contains(_ result: OnboardingSearchResult) -> Bool {
        switch result {
        case .channel(let channel):
            channelIds.contains(channel.channelId)
        case .podcast(let podcast):
            podcast.link.map { feedKeys.contains(Self.feedKey($0)) } ?? false
        }
    }

    private static func feedKey(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = nil
        let key = components?.string ?? url.absoluteString
        return key.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
    }
}
