//
//  SearchVM+Local.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// The Search tab's local half: which sources are searched, and matching the query
/// against what's already stored in the app. See `LocalSearchService` for the matching
/// itself.
extension SearchVM {
    /// The YouTube results minus anything already listed in the local sections above,
    /// so a video that's in the library isn't shown twice.
    var youtubeResults: [SendableVideo] {
        let localIds = Set((localResults.bookmarks + localResults.videos).map(\.youtubeId))
        guard !localIds.isEmpty else { return results }
        return results.filter { !localIds.contains($0.youtubeId) }
    }

    func isEnabled(_ source: SearchSource) -> Bool {
        enabledSources.contains(source)
    }

    func setEnabled(_ source: SearchSource, _ isEnabled: Bool) {
        guard self.isEnabled(source) != isEnabled else { return }
        if isEnabled {
            enabledSources.insert(source)
        } else {
            enabledSources.remove(source)
        }
        SearchSource.persistEnabled(enabledSources)
        Signal.log(
            "Search.SourceToggled",
            parameters: ["source": source.rawValue, "value": isEnabled ? "On" : "Off"]
        )
        if source == .youtube {
            rerunActiveSearch()
        } else {
            // Local sources are matched in the store — no need to hit the API again.
            searchLocal()
        }
    }

    /// Matches the active query against the stored subscriptions/videos. Runs alongside
    /// the (much slower) YouTube request, so local hits show up immediately.
    func searchLocal() {
        localTask?.cancel()
        let query = activeQuery
        let sources = enabledSources.subtracting([.youtube])
        guard !sources.isEmpty else {
            localResults = LocalSearchResults()
            return
        }
        localTask = Task {
            let found = await LocalSearchService.search(query: query, sources: sources)
            if Task.isCancelled || query != activeQuery { return }
            withAnimation {
                localResults = found
            }
        }
    }
}
