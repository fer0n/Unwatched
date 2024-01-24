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

        ScrollViewReader { proxy in
            TabView(selection: $navManager.tab.onUpdate { newValue in
                handleSameTabTapped(newValue, proxy)
            }) {
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
    }

    func markVideoWatched(video: Video) {
        VideoService.markVideoWatched(
            video, modelContext: modelContext
        )
    }

    func handleSameTabTapped(_ newTab: Tab, _ proxy: ScrollViewProxy) {
        if newTab == navManager.tab {
            withAnimation {
                proxy.scrollTo(navManager.topListItemId, anchor: .bottom)
            }
        }
    }
}

struct MenuView_Previews: PreviewProvider {

    static var previews: some View {
        MenuView()
            .modelContainer(DataController.previewContainer)
            .environment(NavigationManager.getDummy())
            .environment(RefreshManager())
            .environment(Alerter())
            .environment(PlayerManager())
    }
}
