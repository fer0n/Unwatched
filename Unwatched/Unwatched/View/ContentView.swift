//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?
    @Environment(SheetPositionReader.self) var sheetPos

    var videoExists: Bool {
        player.video != nil
    }

    var bigScreen: Bool {
        sizeClass == .regular && !Device.isIphone
    }

    var body: some View {
        @Bindable var navManager = navManager

        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let landscapeFullscreen = !bigScreen && isLandscape

            let chapterViewDetent: Set<PresentationDetent> = player.embeddingDisabled
                ? [.medium]
                : [.height(sheetPos.playerControlHeight)]

            ZStack {
                #if os(iOS)
                IOSSPlitView(
                    proxy: proxy,
                    bigScreen: bigScreen,
                    isLandscape: isLandscape,
                    landscapeFullscreen: landscapeFullscreen
                )
                #else
                MacOSSplitView(
                    bigScreen: bigScreen,
                    isLandscape: isLandscape,
                    landscapeFullscreen: landscapeFullscreen
                )
                #endif

                if !bigScreen && !videoExists {
                    VideoNotAvailableView()
                }
            }
            #if os(iOS)
            .environment(\.colorScheme, .dark)
            #endif
            .background(Color.playerBackgroundColor)
            .onChange(of: proxy.safeAreaInsets.top, initial: true) {
                if !landscapeFullscreen {
                    sheetPos.setTopSafeArea(proxy.safeAreaInsets.top)
                }
            }
            .sheet(isPresented: $navManager.showDescriptionDetail) {
                if let video = player.video {
                    ChapterDescriptionView(video: video)
                        .presentationDetents(bigScreen ? [] : chapterViewDetent)
                        .presentationBackgroundInteraction(
                            bigScreen
                                ? .disabled
                                :
                                .enabled(upThrough: .height(sheetPos.playerControlHeight))
                        )
                        .presentationDragIndicator(.hidden)
                        .environment(\.colorScheme, colorScheme)
                }
            }
            .menuViewSheet(
                allowMaxSheetHeight: videoExists && !navManager.searchFocused,
                allowPlayerControlHeight: !player.embeddingDisabled
                    && player.videoAspectRatio > Const.tallestAspectRatio,
                landscapeFullscreen: landscapeFullscreen,
                disableSheet: bigScreen
            )
        }
        .setColorScheme()
        .ignoresSafeArea(bigScreen ? .keyboard : [])
        .onSizeChange { newSize in
            sheetPos.sheetHeight = newSize.height
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(DataProvider.previewContainerFilled)
        .environment(NavigationManager.getDummy(true))
        .environment(Alerter())
        .environment(PlayerManager.getDummy())
        .environment(ImageCacheManager())
        .environment(RefreshManager())
        .environment(SheetPositionReader.shared)
    // .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}
