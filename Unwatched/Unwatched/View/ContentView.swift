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
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    @Environment(SheetPositionReader.self) var sheetPos
    @AppStorage(Const.bigScreenFullscreenToRestore) var fullscreenToRestore = false

    var videoExists: Bool {
        player.video != nil
    }

    var regularSize: Bool {
        Device.isBigScreen(sizeClass, verticalSizeClass)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = ContentLayout(proxy: proxy, regularSize: regularSize)

            ZStack {
                #if os(iOS) || os(visionOS)
                IOSSPlitView(
                    proxy: proxy,
                    bigScreen: layout.bigScreen,
                    isLandscape: layout.isLandscape,
                    landscapeFullscreen: layout.landscapeFullscreen,
                    fold: layout.fold,
                    restoringFullscreen: layout.bigScreen && fullscreenToRestore
                )
                #else
                MacOSSplitView(
                    bigScreen: layout.bigScreen,
                    isLandscape: layout.isLandscape,
                    landscapeFullscreen: layout.landscapeFullscreen
                )
                #endif
            }
            #if os(iOS)
            .environment(\.colorScheme, .dark)
            #endif
            #if !os(visionOS)
            .background(Color.playerBackgroundColor)
            #endif
            .onChange(of: layout, initial: true) {
                applyLayout(layout)
            }
            .onChange(of: proxy.safeAreaInsets.top, initial: true) {
                if !layout.landscapeFullscreen {
                    sheetPos.setTopSafeArea(proxy.safeAreaInsets.top)
                }
            }
            .menuViewSheet(
                allowPlayerControlHeight: !player.limitHeight,
                landscapeFullscreen: layout.landscapeFullscreen,
                floatingSheet: layout.regularSize,
                disableSheet: layout.bigScreen,
                proxy: proxy
            )
            .environment(\.bigScreenLayout, layout.bigScreen)
            .environment(\.playerControlsShortOnHeight, layout.shortOnHeight)
            .environment(\.playerFitsSideBySide, layout.fitsSideBySide)
            .environment(\.landscapeControlBand, layout.controlBand)
        }
        .setColorScheme()
        #if os(iOS)
        .horizontalBars()
        #endif
        .onSizeChange { newSize in
            sheetPos.sheetHeight = newSize.height
        }
        .ignoresSafeArea(.keyboard)
    }

    func applyLayout(_ layout: ContentLayout) {
        let previous = sheetPos.layout
        sheetPos.layout = layout
        if sheetPos.sheetCoversMiniPlayer != layout.shortOnHeight {
            sheetPos.sheetCoversMiniPlayer = layout.shortOnHeight
        }
        sheetPos.setFixedSheetHeight(layout.fixedSheetHeight)
        #if os(iOS)
        if previous?.regularSize != layout.regularSize {
            OrientationManager.updatePodcastOrientationLock()
        }
        if previous?.bigScreen != layout.bigScreen {
            handleBigScreenChanged(layout, wasBigScreen: previous?.bigScreen ?? layout.bigScreen)
        }
        #endif
    }

    #if os(iOS)
    func handleBigScreenChanged(_ layout: ContentLayout, wasBigScreen: Bool) {
        let defaults = UserDefaults.standard
        if layout.bigScreen {
            if fullscreenToRestore {
                fullscreenToRestore = false
                defaults.set(true, forKey: Const.hideControlsFullscreen)
            }
        } else {
            if wasBigScreen && defaults.bool(forKey: Const.hideControlsFullscreen) {
                fullscreenToRestore = true
            }
            defaults.set(false, forKey: Const.hideControlsFullscreen)
            if !layout.landscapeFullscreen && !navManager.showMenu {
                navManager.showMenu = true
            }
        }
    }
    #endif
}

struct ContentLayout: Equatable {
    static let minHeightBelowVideo: CGFloat = 400

    let regularSize: Bool
    let isLandscape: Bool
    let fold: CGRect?
    let bigScreen: Bool
    let landscapeFullscreen: Bool
    let shortOnHeight: Bool
    let fitsSideBySide: Bool
    let fixedSheetHeight: CGFloat?
    let controlBand: ControlBand?

    init(proxy: GeometryProxy, regularSize: Bool) {
        let size = proxy.size
        let isLandscape = size.width > size.height
        let fold = regularSize ? proxy.fold(isLandscape: isLandscape) : nil
        let bigScreen = regularSize && (isLandscape || !(Device.isIphone || Device.isIpad))
        let landscapeFullscreen = !bigScreen && isLandscape

        self.regularSize = regularSize
        self.isLandscape = isLandscape
        self.fold = fold
        self.bigScreen = bigScreen
        self.landscapeFullscreen = landscapeFullscreen
        self.shortOnHeight = !bigScreen && !isLandscape
            && size.height - size.width / Const.defaultVideoAspectRatio < Self.minHeightBelowVideo
        self.fitsSideBySide = !bigScreen && size.width >= PlayerContentView.sideBySideMinWidth
        self.fixedSheetHeight = bigScreen ? nil : fold.map { size.height - $0.maxY }
        self.controlBand = landscapeFullscreen ? proxy.landscapeControlBand : nil
    }
}

#Preview {
    ContentView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.getDummy(true))
        .environment(Alerter())
        .environment(PlayerManager.getDummy())
        .environment(ImageCacheManager())
        .environment(RefreshManager())
        .environment(SheetPositionReader.shared)
        .environment(TinyUndoManager())
        .modifier(CustomAlerter())
        .appNotificationOverlay()
}

#Preview("Podcast") {
    let player = PlayerManager.getTheDailyPodcastDummy()

    return ContentView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.getDummy(true))
        .environment(Alerter())
        .environment(player)
        .environment(ImageCacheManager())
        .environment(RefreshManager())
        .environment(SheetPositionReader.shared)
        .environment(TinyUndoManager())
        .modifier(CustomAlerter())
        .appNotificationOverlay()
}
