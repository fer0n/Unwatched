//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage(Const.refreshOnStartup) var refreshOnStartup = false

    @State var navManager: NavigationManager = {
        return loadNavigationManager()
    }()
    @State var player = PlayerManager()
    @State var refresher = RefreshManager()
    @State var sheetPos = SheetPositionReader()

    var body: some View {
        @Bindable var navManager = navManager

        let videoExists = player.video != nil
        let hideMiniPlayer = (navManager.showMenu && sheetPos.swipedBelow) || navManager.showMenu == false
        let detents: Set<PresentationDetent> = videoExists ? [.height(sheetPos.maxSheetHeight)] : [.large]

        ZStack {
            VideoPlayer(showMenu: $navManager.showMenu)
            MiniPlayerView()
                .opacity(hideMiniPlayer ? 0 : 1)
                .animation(.bouncy(duration: 0.5), value: hideMiniPlayer)
            if !videoExists {
                VideoNotAvailableView()
            }
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
                .onAppear {
                    sheetPos.setNormalSheetHeightDelayed()
                }
                .environment(player)
        }
        .environment(navManager)
        .onAppear {
            refresher.container = modelContext.container
            if refreshOnStartup {
                print("refreshOnStartup")
                refresher.refreshAll()
            }
        }
        .innerSizeTrackerModifier(onChange: { newSize in
            sheetPos.sheetHeight = newSize.height
        })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            saveNavigationManager()
        }
        .onChange(of: player.video) {
            if player.video != nil {
                withAnimation {
                    navManager.showMenu = false
                }
            }
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

    func saveNavigationManager() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(navManager) {
            UserDefaults.standard.set(encoded, forKey: Const.navigationManager)
        }
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
