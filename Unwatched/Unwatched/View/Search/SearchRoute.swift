//
//  SearchRoute.swift
//  Unwatched
//

import UnwatchedShared

/// A page on the Search tab's navigation stack. The results are a page of their own rather than the
/// tab's root because iOS focuses the search field whenever the search tab is selected at its root,
/// which would throw the keyboard over results the user came back to read. macOS keeps them inline.
enum SearchRoute: Hashable {
    case results
    case subscription(SendableSubscription)
    case video(VideoDetailRoute)
}
