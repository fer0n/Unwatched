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
    }
}

#Preview {
    ContentView()
        .environment(ImageCacheManager())
        .modelContainer(DataProvider.previewContainerFilled)
}
