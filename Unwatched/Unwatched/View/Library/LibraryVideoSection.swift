//
//  LibraryVideoSection.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct LibraryVideoSection: View {
    var body: some View {
        MySection("videos", hasPadding: false) {
            NavigationLink(value: LibraryDestination.allVideos) {
                LibraryNavListItem("allVideos",
                                   systemName: Const.allVideosViewSF)
            }
            NavigationLink(value: LibraryDestination.watchHistory) {
                LibraryNavListItem("watched",
                                   systemName: "checkmark")
            }
            NavigationLink(value: LibraryDestination.bookmarkedVideos) {
                LibraryNavListItem("bookmarkedVideos",
                                   systemName: "bookmark.fill")
            }
            NavigationLink(value: LibraryDestination.sideloading) {
                LibraryNavListItem("sideloads",
                                   systemName: "arrow.forward.circle.fill")
            }
        }
        .symbolVariant(.fill)
    }
}

#Preview {
    LibraryVideoSection()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
        .environment(ImageCacheManager())
        .tint(.teal)
}
