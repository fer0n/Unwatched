//
//  ContentView.swift
//  UnwatchedTV
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct ContentView: View {
    @State var imageManager = ImageCacheManager()
    @State var syncer = SyncManager()
    @State var progress = SyncProgress()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            QueueGridView()
                .tabItem {
                    Label("queue", systemImage: "rectangle.stack")
                }
            TvSettingsView()
                .tabItem {
                    Label("settings", systemImage: Const.settingsViewSF)
                }
        }
        .environment(imageManager)
        .environment(syncer)
        .environment(progress)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            NSUbiquitousKeyValueStore.default.synchronize()
            await progress.track(in: modelContext.container)
        }
    }
}

#Preview {
    ContentView()
        .environment(ImageCacheManager())
        .modelContainer(DataProvider.previewContainerFilled)
}
