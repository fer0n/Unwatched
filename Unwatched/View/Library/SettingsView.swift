//
//  SettingsView.swift
//  Unwatched
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager
    @AppStorage(Const.refreshOnStartup) var refreshOnStartup: Bool = false
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.autoplayVideos) var autoplayVideos: Bool = true
    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox

    @AppStorage(Const.handleShortsDifferently) var handleShortsDifferently: Bool = false
    @AppStorage(Const.defaultShortsPlacement) var defaultShortsPlacement: VideoPlacement = .inbox
    @AppStorage(Const.hideShortsEverywhere) var hideShortsEverywhere: Bool = false
    @AppStorage(Const.shortsDetection) var shortsDetection: ShortsDetection = .safe

    var body: some View {
        let topListItemId = NavigationManager.getScrollId("settings")

        VStack {
            List {
                Section {
                    Toggle(isOn: $refreshOnStartup) {
                        Text("refreshOnStartup")
                    }
                }
                .id(topListItemId)
                .tint(.teal)

                Section(header: Text("playback"), footer: Text("playbackHelper")) {
                    Toggle(isOn: $playVideoFullscreen) {
                        Text("startVideosInFullscreen")
                    }
                    Toggle(isOn: $autoplayVideos) {
                        Text("autoplayVideos")
                    }
                }
                .tint(.teal)

                Section("videoSettings") {
                    Picker("newVideos", selection: $defaultVideoPlacement) {
                        ForEach(VideoPlacement.allCases.filter { $0 != .defaultPlacement }, id: \.self) {
                            Text($0.description(defaultPlacement: ""))
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section(header: Text("shortsSettings"), footer: Text("shortsSettingsHelper")) {
                    Picker("shortsDetection", selection: $shortsDetection) {
                        ForEach(ShortsDetection.allCases, id: \.self) {
                            Text($0.description)
                        }
                    }
                    Toggle(isOn: $handleShortsDifferently) {
                        Text("handleShortsDifferently")
                    }
                    .tint(.teal)
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

                Section {
                    LinkItemView(destination: UrlService.writeReviewUrl, label: "rateApp") {
                        Image(systemName: Const.rateAppSF)
                    }

                    LinkItemView(destination: UrlService.emailUrl, label: "contact") {
                        Image(systemName: Const.contactMailSF)
                    }

                    LinkItemView(destination: UrlService.githubUrl, label: "github") {
                        Image("github-logo")
                            .resizable()
                    }
                }

                Section {
                    let feedUrls = AsyncSharableUrls(getUrls: exportAllSubscriptions)
                    ShareLink(item: feedUrls, preview: SharePreview("exportSubscriptions")) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("exportSubscriptions")
                        }
                    }
                }
            }
        }
        .navigationTitle("settings")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.myAccentColor)
        .onAppear {
            navManager.topListItemId = topListItemId
        }
    }

    func exportAllSubscriptions() async -> [(title: String, link: URL)] {
        let container = modelContext.container
        let result = try? await SubscriptionService.getAllFeedUrls(container)
        return result ?? []
    }
}

struct AsyncSharableUrls: Transferable {
    let getUrls: () async -> [(title: String, link: URL)]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { item in
            let urls = await item.getUrls()
            let textUrls = urls
                .map { "\($0.title)\n\($0.link.absoluteString)\n" }
                .joined(separator: "\n")
            print("textUrls", textUrls)
            let data = textUrls.data(using: .utf8)
            if let data = data {
                return data
            } else {
                fatalError()
            }
        }
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
