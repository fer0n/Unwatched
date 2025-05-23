//
//  VideoSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoSettingsView: View {
    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox
    @AppStorage(Const.autoRemoveNew) var autoRemoveNew: Bool = true
    @AppStorage(Const.requireClearConfirmation) var requireClearConfirmation: Bool = true
    @AppStorage(Const.showClearQueueButton) var showClearQueueButton: Bool = true
    @AppStorage(Const.showAddToQueueButton) var showAddToQueueButton: Bool = false
    @AppStorage(Const.autoRefresh) var autoRefresh: Bool = true
    @AppStorage(Const.enableQueueContextMenu) var enableQueueContextMenu: Bool = false
    @AppStorage(Const.autoRefreshIgnoresSync) var autoRefreshIgnoresSync: Bool = false

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                MySection("newVideos", footer: "newVideosFooter") {
                    Picker("newVideos", selection: $defaultVideoPlacement) {
                        ForEach(VideoPlacement.allCases.filter { $0 != .defaultPlacement }, id: \.self) {
                            Text($0.description(defaultPlacement: ""))
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle(isOn: $autoRemoveNew) {
                        Text("autoRemoveNew")
                    }
                }

                MySection("refresh", footer: "allowRefreshDuringSyncFooter") {
                    Toggle(isOn: $autoRefresh) {
                        Text("autoRefresh")
                    }
                    Toggle(isOn: $autoRefreshIgnoresSync) {
                        Text("autoRefreshIgnoresSync")
                    }
                }

                MySection("videoTriage") {
                    Toggle(isOn: $requireClearConfirmation) {
                        Text("requireClearConfirmation")
                    }
                    Toggle(isOn: $showAddToQueueButton) {
                        Text("showAddToQueueButton")
                    }
                }

                MySection("queue") {
                    Toggle(isOn: $showClearQueueButton) {
                        Text("showClearQueueButton")
                    }
                    #if os(iOS)
                    Toggle(isOn: $enableQueueContextMenu) {
                        Text("enableQueueContextMenu")
                    }
                    #endif
                }
            }
            .myNavigationTitle("videoSettings")
        }
    }
}

#Preview {
    VideoSettingsView()
}
