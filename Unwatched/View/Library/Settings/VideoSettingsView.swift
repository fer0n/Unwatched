//
//  VideoSettingsView.swift
//  Unwatched
//

import SwiftUI

struct VideoSettingsView: View {
    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox
    @AppStorage(Const.handleShortsDifferently) var handleShortsDifferently: Bool = false
    @AppStorage(Const.defaultShortsPlacement) var defaultShortsPlacement: VideoPlacement = .inbox
    @AppStorage(Const.hideShortsEverywhere) var hideShortsEverywhere: Bool = false
    @AppStorage(Const.shortsDetection) var shortsDetection: ShortsDetection = .safe
    @AppStorage(Const.requireClearConfirmation) var requireClearConfirmation: Bool = true
    @AppStorage(Const.showClearQueueButton) var showClearQueueButton: Bool = true

    var body: some View {
        Form {
            Section(footer: Text("newVideosHelper")) {
                Picker("newVideos", selection: $defaultVideoPlacement) {
                    ForEach(VideoPlacement.allCases.filter { $0 != .defaultPlacement }, id: \.self) {
                        Text($0.description(defaultPlacement: ""))
                    }
                }
                .pickerStyle(.menu)
            }

            Section("clearVideos") {
                Toggle(isOn: $requireClearConfirmation) {
                    Text("requireClearConfirmation")
                }
                Toggle(isOn: $showClearQueueButton) {
                    Text("showClearQueueButton")
                }
            }

            Section(header: Text("shortsSettings")) {
                Toggle(isOn: $handleShortsDifferently) {
                    Text("handleShortsDifferently")
                }
                Picker("newShorts", selection: $defaultShortsPlacement) {
                    ForEach(VideoPlacement.allCases.filter { $0 != .defaultPlacement }, id: \.self) {
                        Text($0.description(defaultPlacement: ""))
                    }
                }
                .disabled(!handleShortsDifferently)
                .pickerStyle(.menu)
            }

            Section(footer: Text("hideShortsEverywhereHelper")) {
                Toggle(isOn: $hideShortsEverywhere) {
                    Text("hideShortsEverywhere")
                }
                .disabled(!handleShortsDifferently)
            }

            Section(footer: Text("shortsSettingsHelper")) {
                Picker("shortsDetection", selection: $shortsDetection) {
                    ForEach(ShortsDetection.allCases, id: \.self) {
                        Text($0.description)
                    }
                }
                .disabled(!handleShortsDifferently)
            }
        }
        .navigationTitle("videoSettings")
    }
}

#Preview {
    VideoSettingsView()
}
