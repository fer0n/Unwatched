//
//  MenuView.swift
//  Unwatched
//

import SwiftUI

import SwiftData

struct MenuView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Query var queue: [QueueEntry]
    @Query(animation: .default) var inbox: [InboxEntry]

    var body: some View {
        @Bindable var navManager = navManager
        TabView(selection: $navManager.tab) {
            QueueView()
                .tabItem {
                    Image(systemName: Const.queueTagSF)
                }
                .tag(Tab.queue)

            InboxView()
                .tabItem {
                    Image(systemName: inbox.isEmpty ? Const.inboxTabEmptySF : Const.inboxTabFullSF)
                }
                .tag(Tab.inbox)

            LibraryView()
                .tabItem {
                    Image(systemName: Const.libraryTabSF)
                }
                .tag(Tab.library)
        }
        .environment(navManager)
        .tint(.myAccentColor)
    }

    func markVideoWatched(video: Video) {
        VideoService.markVideoWatched(
            video, modelContext: modelContext
        )
    }

}

struct MenuView_Previews: PreviewProvider {

    static var previews: some View {
        MenuView()
    }
}
