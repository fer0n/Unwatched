//
//  VideoSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct GeneralSettingsView: View {
    @AppStorage(Const.browserDisplayMode) var browserDisplayMode: BrowserDisplayMode = .inApp
    @AppStorage(Const.searchAlwaysUseYoutube) var searchAlwaysUseYoutube: Bool = false
    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox
    @AppStorage(Const.autoClearNew) var autoClearNew: Bool = false
    @AppStorage(Const.requireClearConfirmation) var requireClearConfirmation: Bool = true
    @AppStorage(Const.showClearQueueButton) var showClearQueueButton: Bool = true
    @AppStorage(Const.showAddToQueueButton) var showAddToQueueButton: Bool = false
    @AppStorage(Const.inboxOldestFirst) var inboxOldestFirst: Bool = false
    @AppStorage(Const.autoRefresh) var autoRefresh: Bool = true
    @AppStorage(Const.enableQueueContextMenu) var enableQueueContextMenu: Bool = false
    @AppStorage(Const.autoRefreshIgnoresSync) var autoRefreshIgnoresSync: Bool = false
    @AppStorage(Const.shareExtensionAction, store: .appGroup)
    var shareExtensionAction: ShareExtensionActionSetting = .askEveryTime

    var body: some View {
        ZStack {
            MyBackgroundColor(macOS: false)

            MyForm {
                MySection {
                    Picker("newVideos", selection: $defaultVideoPlacement) {
                        ForEach(VideoPlacement.allCases.filter { $0 != .defaultPlacement }, id: \.self) {
                            Text($0.description(defaultPlacement: ""))
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("openLinks", selection: $browserDisplayMode) {
                        ForEach(BrowserDisplayMode.allCases, id: \.self) {
                            Text($0.description)
                        }
                    }
                    .pickerStyle(.menu)
                    Toggle(isOn: $searchAlwaysUseYoutube) {
                        Text("searchAlwaysUseYoutube")
                    }
                    Toggle(isOn: $autoClearNew) {
                        Text("autoClearNew")
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
                    InboxSortOrderPicker(oldestFirst: $inboxOldestFirst)
                        .pickerStyle(.menu)
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

                MySection(footer: "shareExtensionActionFooter") {
                    Picker("shareExtensionAction", selection: $shareExtensionAction) {
                        ForEach(ShareExtensionActionSetting.allCases, id: \.self) {
                            Text($0.title)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .myNavigationTitle("generalSettings")
        }
    }
}

#Preview {
    GeneralSettingsView()
}
