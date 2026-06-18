//
//  MenuView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct MenuView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager

    @AppStorage(Const.showTabBarLabels) var showTabBarLabels = true

    #if os(macOS)
    @AppStorage(Const.videoListFormat) var videoListFormat: VideoListFormat = .compact
    #endif

    var showCancelButton = false
    var showTabBar = true
    var isSidebar = false

    var shouldShowCancelButton: Bool {
        return false
    }

    var body: some View {
        @Bindable var navManager = navManager

        ScrollViewReader { proxy in
            TabView(selection: $navManager.tab.onUpdate { newValue in
                handleTabChanged(newValue, proxy)
            }) {
                Tab(value: NavigationTab.queue) {
                    QueueTabItemView(showCancelButton: showCancelButton)
                } label: {
                    QueueTabLabel()
                }

                Tab(value: NavigationTab.inbox) {
                    InboxTabItemView(showCancelButton: showCancelButton)
                } label: {
                    InboxTabLabel()
                }

                Tab(value: NavigationTab.library) {
                    LibraryView(showCancelButton: shouldShowCancelButton)
                } label: {
                    MenuTabLabel(image: Image(systemName: "books.vertical"), tag: .library)
                }

                Tab(value: NavigationTab.search, role: .search) {
                    SearchView()
                }
            }
            #if os(iOS)
            .scrollEdgeEffectHidden(for: .bottom)
            #endif
            #if os(macOS)
            .popover(isPresented: showVideoDetail) {
                Group {
                    if let video = navManager.videoDetail {
                        videoDetailContent(video)
                    }
                }
            }
            #elseif os(visionOS)
            .sheet(isPresented: showVideoDetail) {
            Group {
            if let video = navManager.videoDetail {
            NavigationStack {
            videoDetailContent(video)
            .toolbar {
            ToolbarItem(placement: .cancellationAction) {
            DismissSheetButton()
            }
            }
            }
            }
            }
            }
            #else
            .sheet(isPresented: showVideoDetail) {
            Group {
            if let video = navManager.videoDetail {
            videoDetailContent(video)
            }
            }
            }
            #endif
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.scrollViewProxy, proxy)
        }
        #if os(macOS)
        .id(videoListFormat == .compact) // workaround: expansive thumbnail size when switching setting
        #endif
        .browserViewSheet(navManager: $navManager)
        .premiumOfferSheet()
        .background {
            (Const.macOS26 || Device.isVision
                ? Color.clear
                : Color.backgroundColor)
                .ignoresSafeArea(.all)
        }
    }

    func videoDetailContent(_ video: Video) -> some View {
        ZStack {
            MyBackgroundColor(macOS: false)
            ChapterDescriptionView(video: video, isTransparent: Device.isVision)
                .presentationDragIndicator(.hidden)
        }
        .environment(\.colorScheme, colorScheme)
        .appNotificationOverlay(topPadding: 10)
    }

    @MainActor
    func handleTabChanged(_ newTab: NavigationTab, _ proxy: ScrollViewProxy) {
        Log.info("handleTabChanged \(newTab.rawValue)")
        if newTab == navManager.tab {
            let isTopView = navManager.handleTappedTwice()
            Task { @MainActor in
                withAnimation {
                    if isTopView {
                        proxy.scrollTo(navManager.topListItemId, anchor: .bottom)
                    }
                }
            }
        }
    }

    var showVideoDetail: Binding<Bool> {
        Binding<Bool>(
            get: { navManager.videoDetail != nil },
            set: { isPresented in
                if !isPresented {
                    navManager.videoDetail = nil
                }
            }
        )
    }
}

#Preview {
    MenuView(showCancelButton: false)
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(RefreshManager())
        .environment(Alerter())
        .environment(PlayerManager())
        .environment(ImageCacheManager())
}
