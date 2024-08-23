//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false
    @AppStorage(Const.lightPlayer) var lightPlayer: Bool = false

    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        @Bindable var navManager = navManager
        let videoExists = player.video != nil
        let bigScreen = sizeClass == .regular && !UIDevice.isIphone

        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let layout = isLandscape
                ? AnyLayout(HStackLayout())
                : AnyLayout(VStackLayout())
            let landscapeFullscreen = !bigScreen && isLandscape

            let chapterViewDetent: Set<PresentationDetent> = player.embeddingDisabled
                ? [.medium]
                : [.height(sheetPos.playerControlHeight)]

            ZStack {
                layout {
                    VideoPlayer(
                        compactSize: bigScreen,
                        showInfo: !bigScreen || (isLandscape && bigScreen) && !hideControlsFullscreen,
                        horizontalLayout: hideControlsFullscreen,
                        landscapeFullscreen: landscapeFullscreen
                    )
                    .frame(maxHeight: .infinity)

                    if bigScreen && !hideControlsFullscreen {
                        MenuView()
                            .frame(maxWidth: isLandscape
                                    ? min(proxy.size.width * 0.4, 400)
                                    : nil)
                    }
                }
                if !bigScreen && !videoExists {
                    VideoNotAvailableView()
                }
            }
            .animation(.default, value: hideControlsFullscreen)
            .background(Color.playerBackgroundColor)
            .environment(\.colorScheme, lightPlayer ? colorScheme : .dark)
            .onAppear {
                sheetPos.setTopSafeArea(proxy.safeAreaInsets.top)
            }
            .sheet(isPresented: $navManager.showDescriptionDetail) {
                if let video = player.video {
                    ChapterDescriptionView(video: video, page: $navManager.selectedDetailPage)
                        .presentationDetents(chapterViewDetent)
                        .presentationBackgroundInteraction(
                            .enabled(upThrough: .height(sheetPos.playerControlHeight))
                        )
                        .presentationDragIndicator(.visible)
                }
            }
            .menuViewSheet(allowMaxSheetHeight: videoExists && !navManager.searchFocused,
                           embeddingDisabled: player.embeddingDisabled,
                           showCancelButton: landscapeFullscreen,
                           disableSheet: bigScreen
            )
        }
        .ignoresSafeArea(bigScreen ? .keyboard : [])
        .onSizeChange { newSize in
            sheetPos.sheetHeight = newSize.height
        }
    }
}

struct ContentView_Previews: PreviewProvider {

    static var previews: some View {
        let player = PlayerManager()
        player.video = Video.getDummy()

        return ContentView(hideControlsFullscreen: false, lightPlayer: true)
            .modelContainer(DataController.previewContainer)
            .environment(NavigationManager.getDummy())
            .environment(Alerter())
            .environment(player)
            .environment(ImageCacheManager())
            .environment(RefreshManager())
            .environment(SheetPositionReader())
    }
}
