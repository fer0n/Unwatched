//
//  VideoSettingsView.swift
//  Unwatched
//

import SwiftUI

struct VideoSettingsView: View {
    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox
    @AppStorage(Const.hideShortsEverywhere) var hideShortsEverywhere: Bool = false
    @AppStorage(Const.requireClearConfirmation) var requireClearConfirmation: Bool = true
    @AppStorage(Const.showClearQueueButton) var showClearQueueButton: Bool = true
    @AppStorage(Const.mergeSponsorBlockChapters) var mergeSponsorBlockChapters: Bool = false
    @AppStorage(Const.forceYtWatchHistory) var forceYtWatchHistory: Bool = false
    @AppStorage(Const.autoRefresh) var autoRefresh: Bool = true

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                MySection {
                    Picker("newVideos", selection: $defaultVideoPlacement) {
                        ForEach(VideoPlacement.allCases.filter { $0 != .defaultPlacement }, id: \.self) {
                            Text($0.description(defaultPlacement: ""))
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle(isOn: $autoRefresh) {
                        Text("autoRefresh")
                    }
                }

                MySection("clearVideos") {
                    Toggle(isOn: $requireClearConfirmation) {
                        Text("requireClearConfirmation")
                    }
                    Toggle(isOn: $showClearQueueButton) {
                        Text("showClearQueueButton")
                    }
                }

                MySection("shortsSettings", footer: "hideShortsEverywhereHelper") {
                    Toggle(isOn: $hideShortsEverywhere) {
                        Text("hideShortsEverywhere")
                    }
                }

                MySection("youtube", footer: "forceYtWatchHistoryHelper") {
                    Toggle(isOn: $forceYtWatchHistory) {
                        Text("forceYtWatchHistory")
                    }
                    .onChange(of: forceYtWatchHistory) { _, _ in
                        PlayerManager.reloadPlayer()
                    }
                }

                MySection("sponsorBlockSettings", footer: "sponsorBlockSettingsHelper") {
                    Toggle(isOn: $mergeSponsorBlockChapters) {
                        Text("sponsorBlockChapters")
                    }
                }
            }
            .myNavigationTitle("videoSettings")
        }
    }
}

#Preview {
    VideoSettingsView()
}
