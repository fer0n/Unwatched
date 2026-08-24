//
//  SearchSource.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Where the Search tab looks for results: `youtube` and `podcasts` are remote searches (InnerTube and the podcast
/// directory), the others match against what's already stored in the app.
enum SearchSource: String, CaseIterable, Identifiable, Sendable {
    case subscriptions
    case bookmarks
    case library
    case podcasts
    case youtube

    var id: String { rawValue }

    var label: Text {
        switch self {
        case .subscriptions: Text("subscriptions")
        case .bookmarks: Text("bookmarkedVideos")
        case .library: Text("library")
        case .podcasts: Text("podcasts")
        case .youtube: Text(verbatim: "YouTube")
        }
    }

    var systemImage: String {
        switch self {
        case .subscriptions: "person.2.fill"
        case .bookmarks: "bookmark.fill"
        case .library: Const.allVideosViewSF
        case .podcasts: Const.podcastSF
        case .youtube: Const.youtubeSF
        }
    }

    static let all = Set(SearchSource.allCases)

    static func loadEnabled() -> Set<SearchSource> {
        guard let raw = UserDefaults.standard.array(forKey: Const.searchSources) as? [String] else {
            return all
        }
        return Set(raw.compactMap(SearchSource.init(rawValue:)))
    }

    static func persistEnabled(_ sources: Set<SearchSource>) {
        UserDefaults.standard.set(sources.map(\.rawValue), forKey: Const.searchSources)
    }
}
