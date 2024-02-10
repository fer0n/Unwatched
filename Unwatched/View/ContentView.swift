//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?

    @State var sheetPos = SheetPositionReader()

    var body: some View {
        @Bindable var navManager = navManager

        let videoExists = player.video != nil
        let detents: Set<PresentationDetent> = videoExists && !navManager.searchFocused
            ? Set([.height(sheetPos.maxSheetHeight)]).union(
                player.embeddingDisabled
                    ? []
                    : [.height(sheetPos.playerControlHeight)]
            )
            : [.large]

        let chapterViewDetent: Set<PresentationDetent> = player.embeddingDisabled
            ? [.medium]
            : [.height(sheetPos.playerControlHeight)]

        let selectedDetent = Binding(
            get: { sheetPos.selectedDetent ?? detents.first ?? .large },
            set: { sheetPos.selectedDetent = $0 }
        )

        let bigScreen = sizeClass == .regular

        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let layout = isLandscape ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())

            ZStack {
                layout {
                    VideoPlayer(showMenu: bigScreen ? .constant(false) : $navManager.showMenu,
                                compactSize: bigScreen,
                                showInfo: isLandscape && bigScreen,
                                showFullscreenButton: bigScreen)
                    if bigScreen {
                        MenuView()
                            .frame(maxWidth: isLandscape
                                    ? min(proxy.size.width * 0.4, 400)
                                    : nil)
                    }
                }
                if !bigScreen {
                    MiniPlayerView()
                    if !videoExists {
                        VideoNotAvailableView()
                    }
                }
            }
            .environment(sheetPos)
            .background(Color.backgroundColor)
            .environment(\.colorScheme, .dark)
            .onAppear {
                sheetPos.setTopSafeArea(proxy.safeAreaInsets.top)
            }
            .sheet(isPresented: $navManager.showDescriptionDetail) {
                ChapterDescriptionView()
                    .presentationDetents(chapterViewDetent)
                    .presentationBackgroundInteraction(
                        .enabled(upThrough: .height(sheetPos.playerControlHeight))
                    )
            }
            .sheet(isPresented: $navManager.showMenu) {
                MenuView()
                    .presentationDetents(detents, selection: selectedDetent)
                    .presentationBackgroundInteraction(
                        .enabled(upThrough: .height(sheetPos.maxSheetHeight))
                    )
                    .presentationContentInteraction(.scrolls)
                    .globalMinYTrackerModifier(onChange: sheetPos.handleSheetMinYUpdate)
                    .presentationDragIndicator(navManager.searchFocused
                                                ? .hidden
                                                : .visible)
            }
        }
        .innerSizeTrackerModifier(onChange: { newSize in
            sheetPos.sheetHeight = newSize.height
        })
    }
}

struct ContentView_Previews: PreviewProvider {

    static var previews: some View {
        ContentView()
            .modelContainer(DataController.previewContainer)
            .environment(NavigationManager.getDummy())
            .environment(Alerter())
            .environment(PlayerManager())
            .environment(ImageCacheManager())
            .environment(RefreshManager())
    }
}
