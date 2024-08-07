//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false

    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?
    @Environment(SheetPositionReader.self) var sheetPos

    var body: some View {
        @Bindable var navManager = navManager
        let videoExists = player.video != nil
        let bigScreen = sizeClass == .regular

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
            .background(Color.black)
            .environment(\.colorScheme, .dark)
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
        .innerSizeTrackerModifier(onChange: { newSize in
            sheetPos.sheetHeight = newSize.height
        })
    }
}

struct ContentView_Previews: PreviewProvider {

    static var previews: some View {
        ContentView(hideControlsFullscreen: true)
            .modelContainer(DataController.previewContainer)
            .environment(NavigationManager.getDummy())
            .environment(Alerter())
            .environment(PlayerManager())
            .environment(ImageCacheManager())
            .environment(RefreshManager())
            .environment(SheetPositionReader())
    }
}
