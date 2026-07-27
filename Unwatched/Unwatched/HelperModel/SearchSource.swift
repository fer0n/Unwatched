//
//  SearchSource.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Where the Search tab looks for results: `youtube` is the remote InnerTube search,
/// the others match against what's already stored in the app. Each can be toggled
/// individually from the search filter menu; the selection is persisted in
/// `Const.searchSources` (a missing entry means "all enabled").
/// Declaration order is meaningful: `allCases` drives the filter menu, which is kept in
/// the same order the sections appear in the results.
enum SearchSource: String, CaseIterable, Identifiable, Sendable {
    case subscriptions
    case bookmarks
    case library
    case youtube

    var id: String { rawValue }

    var label: Text {
        switch self {
        case .subscriptions: Text("subscriptions")
        case .bookmarks: Text("bookmarkedVideos")
        case .library: Text("library")
        case .youtube: Text(verbatim: "YouTube")
        }
    }

    var systemImage: String {
        switch self {
        case .subscriptions: "person.2.fill"
        case .bookmarks: "bookmark.fill"
        case .library: Const.allVideosViewSF
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
