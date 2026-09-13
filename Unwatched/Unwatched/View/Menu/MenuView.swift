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
    @Environment(NavigationManager.self) var navManager

    var body: some View {
        @Bindable var navManager = navManager

        ScrollViewReader { proxy in
            TabView(selection: $navManager.tab.onUpdate { newValue in
                handleTabChanged(newValue, proxy)
            }) {
                Tab(value: NavigationTab.queue) {
                    QueueTabItemView()
                } label: {
                    QueueTabLabel()
                }

                Tab(value: NavigationTab.inbox) {
                    InboxTabItemView()
                } label: {
                    InboxTabLabel()
                }

                Tab(value: NavigationTab.library) {
                    LibraryView()
                } label: {
                    MenuTabLabel(image: Image(systemName: "books.vertical"), tag: .library)
                }

                Tab(value: NavigationTab.search, role: .search) {
                    SearchView()
                }
            }
            #if os(iOS)
            .scrollEdgeEffectHidden(for: .bottom)
            .scrollEdgeEffectStyle(.soft, for: .top)
            #endif
            #if !os(macOS) && !os(visionOS)
            // Constant on purpose: read live, so flipping it mid-typing rebuilds the tab bar's
            // search presentation and the field jumps to the top.
            .tabViewSearchActivation(.searchTabSelection)
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
            #if !os(macOS)
            // Tapping the search tab again asks for a new search; the results page pops on its own.
            if newTab == .search && isTopView {
                navManager.pendingSearchFocus = true
            }
            #endif
            Task { @MainActor in
                withAnimation {
                    if isTopView {
                        proxy.scrollTo(navManager.topListItemId, anchor: .bottom)
                    }
                }
            }
        } else if newTab == .search {
            #if os(macOS)
            if navManager.searchTabShouldAutoFocus {
                navManager.pendingSearchFocus = true
            }
            #endif
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
    MenuView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(RefreshManager())
        .environment(Alerter())
        .environment(PlayerManager())
        .environment(ImageCacheManager())
}
