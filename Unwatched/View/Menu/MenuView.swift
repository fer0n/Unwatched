//
//  MenuView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

struct MenuView: View {
    @Environment(RefreshManager.self) var refresher
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager

    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @AppStorage(Const.newQueueItemsCount) var newQueueItemsCount: Int = 0
    @AppStorage(Const.showTabBarBadge) var showTabBarBadge: Bool = true
    @AppStorage(Const.browserAsTab) var browserAsTab: Bool = false
    @AppStorage(Const.sheetOpacity) var sheetOpacity: Bool = false

    var showCancelButton: Bool = false

    var body: some View {
        @Bindable var navManager = navManager

        ScrollViewReader { proxy in
            TabView(selection: $navManager.tab.onUpdate { newValue in
                handleTabChanged(newValue, proxy)
            }) {
                TabItemView(image: Image(systemName: Const.queueTagSF),
                            text: "queue",
                            tag: NavigationTab.queue,
                            showBadge: showTabBarBadge && newQueueItemsCount > 0) {
                    QueueView(showCancelButton: showCancelButton)
                }

                InboxTabItemView(showCancelButton: showCancelButton,
                                 showBadge: showTabBarBadge)

                TabItemView(image: Image(systemName: "books.vertical"),
                            text: "library",
                            tag: NavigationTab.library) {
                    LibraryView(showCancelButton: showCancelButton)
                }

                TabItemView(image: Image(systemName: "globe.desk"),
                            text: "browserShort",
                            tag: NavigationTab.browser,
                            show: browserAsTab) {
                    BrowserView(
                        container: modelContext.container,
                        refresher: refresher,
                        url: $navManager.openTabBrowserUrl,
                        showHeader: false,
                        safeArea: false
                    )
                }

            }
            .sheet(item: $navManager.videoDetail) { video in
                ChapterDescriptionView(video: video, page: $navManager.videoDetailPage)
                    .presentationDragIndicator(.visible)
            }
        }
        .browserViewSheet(navManager: $navManager)
        .background {
            Color.backgroundColor.ignoresSafeArea(.all)
        }
        .onAppear {
            customizeTabBarAppearance()
        }
        .onChange(of: sheetOpacity) {
            customizeTabBarAppearance(reload: true)
        }
    }

    @MainActor
    func customizeTabBarAppearance(reload: Bool = false) {
        let appearance = UITabBarAppearance()
        if sheetOpacity {
            appearance.backgroundColor = UIColor(Color.backgroundColor).withAlphaComponent(Const.sheetOpacityValue)
            UITabBar.appearance().standardAppearance = appearance
        } else {
            appearance.backgroundColor = UIColor(Color.backgroundColor)
            appearance.backgroundImage = nil
            appearance.shadowImage = nil

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().barTintColor = UIColor(Color.backgroundColor)
            UITabBar.appearance().backgroundImage = UIImage()
            UITabBar.appearance().backgroundColor = UIColor(Color.backgroundColor)
        }
        if reload {
            UIApplication
                .shared
                .connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .reload()
        }
    }

    func handleTabChanged(_ newTab: NavigationTab, _ proxy: ScrollViewProxy) {
        Logger.log.info("handleTabChanged \(newTab.rawValue)")
        if newTab == navManager.tab {
            withAnimation {
                let isTopView = navManager.handleTappedTwice()
                if isTopView {
                    proxy.scrollTo(navManager.topListItemId, anchor: .bottom)
                }
            }
        }
        if newTab == .inbox {
            UserDefaults.standard.set(0, forKey: Const.newInboxItemsCount)
        } else if newTab == .queue {
            UserDefaults.standard.set(0, forKey: Const.newQueueItemsCount)
        }
    }
}

#Preview {
    MenuView(showCancelButton: false)
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(RefreshManager())
        .environment(Alerter())
        .environment(PlayerManager())
}
