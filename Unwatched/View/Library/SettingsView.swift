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
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true

    @AppStorage(Const.handleShortsDifferently) var handleShortsDifferently: Bool = false
    @AppStorage(Const.defaultShortsPlacement) var defaultShortsPlacement: VideoPlacement = .inbox
    @AppStorage(Const.hideShortsEverywhere) var hideShortsEverywhere: Bool = false
    @AppStorage(Const.shortsDetection) var shortsDetection: ShortsDetection = .safe

    @State var isDeleting = false
    @State var isExporting = false

    var body: some View {
        let topListItemId = NavigationManager.getScrollId("settings")

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

                Section("appearance") {
                    Toggle(isOn: $showTabBarLabels) {
                        Text("showTabBarLabels")
                    }
                }
                .id(topListItemId)
                .tint(.teal)

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
                    let feedUrls = AsyncSharableUrls(getUrls: exportAllSubscriptions, isLoading: $isExporting)
                    ShareLink(item: feedUrls, preview: SharePreview("exportSubscriptions")) {
                        if isExporting {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("exportSubscriptions")
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive, action: {
                        deleteImageCache()
                    }, label: {
                        if isDeleting {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text("deleteImageCache")
                        }
                    })
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

    func deleteImageCache() {
        if isDeleting { return }
        let container = modelContext.container
        isDeleting = true
        Task {
            let task = ImageService.deleteAllImages(container)
            try? await task.value
            await MainActor.run {
                self.isDeleting = false
            }
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
    @Binding var isLoading: Bool

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { item in
            item.isLoading = true
            let urls = await item.getUrls()
            let textUrls = urls
                .map { "\($0.title)\n\($0.link.absoluteString)\n" }
                .joined(separator: "\n")
            print("textUrls", textUrls)
            let data = textUrls.data(using: .utf8)
            if let data = data {
                item.isLoading = false
                return data
            } else {
                fatalError()
            }
            item.isLoading = false
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
