//
//  LibraryVideoSection.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct LibraryVideoSection: View {
    @Query(filter: #Predicate<Subscription> { $0.isArchived == true })
    var sideloads: [Subscription]

    var hasSideloads: Bool {
        !sideloads.isEmpty
    }

    var body: some View {
        MySection("videos") {
            NavigationLink(value: LibraryDestination.allVideos) {
                LibraryNavListItem("allVideos",
                                   systemName: "play.rectangle.on.rectangle.fill")
            }
            NavigationLink(value: LibraryDestination.watchHistory) {
                LibraryNavListItem("watched",
                                   systemName: "checkmark")
            }
            NavigationLink(value: LibraryDestination.bookmarkedVideos) {
                LibraryNavListItem("bookmarkedVideos",
                                   systemName: "bookmark.fill")
            }
            if hasSideloads {
                NavigationLink(value: LibraryDestination.sideloading) {
                    LibraryNavListItem("sideloads",
                                       systemName: "arrow.forward.circle.fill")
                }
            }
        }
    }
}
