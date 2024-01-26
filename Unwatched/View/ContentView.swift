//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @State var navManager: NavigationManager = {
        return loadNavigationManager()
    }()
    @State var player = PlayerManager()
    @State var refresher = RefreshManager()
    @State var sheetPos = SheetPositionReader()
    @State var imageCacheManager = ImageCacheManager()

    var body: some View {
        @Bindable var navManager = navManager

        let videoExists = player.video != nil
        let hideMiniPlayer = (navManager.showMenu && sheetPos.swipedBelow) || navManager.showMenu == false
        let detents: Set<PresentationDetent> = videoExists ? [.height(sheetPos.maxSheetHeight)] : [.large]

        GeometryReader { proxy in
            ZStack {
                VideoPlayer(showMenu: $navManager.showMenu)
                MiniPlayerView()
                    .opacity(hideMiniPlayer ? 0 : 1)
                    .animation(.bouncy(duration: 0.5), value: hideMiniPlayer)
                if !videoExists {
                    VideoNotAvailableView()
                }
            }
            .onAppear {
                sheetPos.setTopSafeArea(proxy.safeAreaInsets.top)
            }
            .environment(player)
            .sheet(isPresented: $navManager.showMenu) {
                MenuView()
                    .environment(refresher)
                    .presentationDetents(detents)
                    .presentationBackgroundInteraction(
                        .enabled(upThrough: .height(sheetPos.maxSheetHeight))
                    )
                    .globalMinYTrackerModifier(onChange: sheetPos.handleSheetMinYUpdate)
                    .environment(player)
            }
        }
        .environment(navManager)
        .environment(imageCacheManager)
        .onAppear {
            let container = modelContext.container
            refresher.container = container
            player.container = container
            restoreNowPlayingVideo()
            refresher.refreshOnStartup()
        }
        .innerSizeTrackerModifier(onChange: { newSize in
            sheetPos.sheetHeight = newSize.height
        })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            saveData()
        }
    }

    func restoreNowPlayingVideo() {
        print("restoreVideo")
        var video: Video?

        if let data = UserDefaults.standard.data(forKey: Const.nowPlayingVideo),
           let videoId = try? JSONDecoder().decode(Video.ID.self, from: data) {
            if player.video?.persistentModelID == videoId {
                // current video is the one stored, all good
                return
            }
            video = modelContext.model(for: videoId) as? Video
        }

        if let video = video {
            player.setNextVideo(video, .nextUp)
        } else {
            player.loadTopmostVideoFromQueue()
        }
    }

    static func loadNavigationManager() -> NavigationManager {
        print("loadNavigationManager")
        if let savedNavManager = UserDefaults.standard.data(forKey: Const.navigationManager) {
            print("loading savedNav")
            if let loadedNavManager = try? JSONDecoder().decode(
                NavigationManager.self,
                from: savedNavManager
            ) {
                print("found state")
                return loadedNavManager
            } else {
                print("not found")
            }
        }
        return NavigationManager()
    }

    func saveData() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(navManager) {
            UserDefaults.standard.set(encoded, forKey: Const.navigationManager)
        }

        let videoId = player.video?.persistentModelID
        let data = try? JSONEncoder().encode(videoId)
        UserDefaults.standard.setValue(data, forKey: Const.nowPlayingVideo)
        let container = modelContext.container
        imageCacheManager.persistCache(container)
        print("saved state")
    }
}

struct ContentView_Previews: PreviewProvider {

    static var previews: some View {
        ContentView()
            .modelContainer(DataController.previewContainer)
            .environment(NavigationManager.getDummy())
            .environment(Alerter())
    }
}
