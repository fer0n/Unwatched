//
//  MenuView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct MenuView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @Query var queue: [QueueEntry]
    @Query(animation: .default) var inbox: [InboxEntry]

    var body: some View {
        @Bindable var navManager = navManager

        ScrollViewReader { proxy in
            TabView(selection: $navManager.tab.onUpdate { newValue in
                handleSameTabTapped(newValue, proxy)
            }) {
                QueueView(inboxHasEntries: !inbox.isEmpty)
                    .tabItem {
                        Image(systemName: Const.queueTagSF)
                        if showTabBarLabels {
                            Text("queue")
                        }
                    }
                    .tag(Tab.queue)

                InboxView()
                    .tabItem {
                        Image(systemName: inbox.isEmpty ? Const.inboxTabEmptySF : Const.inboxTabFullSF)
                        if showTabBarLabels {
                            Text("inbox")
                        }
                    }
                    .tag(Tab.inbox)

                LibraryView()
                    .tabItem {
                        Image(systemName: Const.libraryTabSF)
                        if showTabBarLabels {
                            Text("library")
                        }
                    }
                    .tag(Tab.library)
            }
            .environment(navManager)
            .tint(.myAccentColor)
        }
        .sheet(isPresented: $navManager.showBrowserSheet) {
            BrowserView()
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
                let isTopView = navManager.handleTappedTwice()
                if isTopView {
                    proxy.scrollTo(navManager.topListItemId, anchor: .bottom)
                }
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
