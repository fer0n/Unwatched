//
//  SettingsView.swift
//  Unwatched
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) var modelContext

    @AppStorage(Const.refreshOnStartup) var refreshOnStartup: Bool = true
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.autoplayVideos) var autoplayVideos: Bool = true
    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true

    @AppStorage(Const.handleShortsDifferently) var handleShortsDifferently: Bool = false
    @AppStorage(Const.defaultShortsPlacement) var defaultShortsPlacement: VideoPlacement = .inbox
    @AppStorage(Const.hideShortsEverywhere) var hideShortsEverywhere: Bool = false
    @AppStorage(Const.shortsDetection) var shortsDetection: ShortsDetection = .safe

    var body: some View {
        VStack {
            List {
                Section("videoSettings") {
                    Picker("newVideos", selection: $defaultVideoPlacement) {
                        ForEach(VideoPlacement.allCases.filter { $0 != .defaultPlacement }, id: \.self) {
                            Text($0.description(defaultPlacement: ""))
                        }
                    }
                    .pickerStyle(.menu)
                    Toggle(isOn: $refreshOnStartup) {
                        Text("refreshOnStartup")
                    }
                    .tint(.teal)
                }

                Section(header: Text("playback"), footer: Text("playbackHelper")) {
                    Toggle(isOn: $autoplayVideos) {
                        Text("autoplayVideos")
                    }
                    Toggle(isOn: $playVideoFullscreen) {
                        Text("startVideosInFullscreen")
                    }
                }
                .tint(.teal)

                Section(header: Text("shortsSettings"), footer: Text("shortsSettingsHelper")) {
                    Toggle(isOn: $handleShortsDifferently) {
                        Text("handleShortsDifferently")
                    }
                    .tint(.teal)
                    Picker("shortsDetection", selection: $shortsDetection) {
                        ForEach(ShortsDetection.allCases, id: \.self) {
                            Text($0.description)
                        }
                    }
                    .disabled(!handleShortsDifferently)
                    Toggle(isOn: $hideShortsEverywhere) {
                        Text("hideShortsEverywhere")
                    }
                    .tint(.teal)
                    .disabled(!handleShortsDifferently)
                    Picker("newShorts", selection: $defaultShortsPlacement) {
                        ForEach(VideoPlacement.allCases.filter { $0 != .defaultPlacement }, id: \.self) {
                            Text($0.description(defaultPlacement: ""))
                        }
                    }
                    .disabled(!handleShortsDifferently)
                    .pickerStyle(.menu)
                }

                Section("appearance") {
                    Toggle(isOn: $showTabBarLabels) {
                        Text("showTabBarLabels")
                    }
                }
                .tint(.teal)

                Section("contact") {
                    // LinkItemView(destination: UrlService.writeReviewUrl, label: "rateApp") {
                    //    Image(systemName: Const.rateAppSF)
                    // }

                    LinkItemView(destination: UrlService.emailUrl, label: "contactUs") {
                        Image(systemName: Const.contactMailSF)
                    }

                    // LinkItemView(destination: UrlService.githubUrl, label: "github") {
                    //    Image("github-logo")
                    //        .resizable()
                    // }
                }

                Section {
                    NavigationLink(value: LibraryDestination.userData) {
                        Text("userData")
                    }
                }
            }
        }
        .navigationTitle("settings")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.myAccentColor)
    }
}

struct LinkItemView<Content: View>: View {
    let destination: URL
    let label: LocalizedStringKey
    let content: () -> Content

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 20) {
                content()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.myAccentColor)
                Text(label)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: Const.listItemChevronSF)
                    .foregroundColor(.myAccentColor)
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
}
