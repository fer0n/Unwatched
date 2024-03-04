//
//  SettingsView.swift
//  Unwatched
//

import SwiftUI
import OSLog

private let log = Logger(subsystem: Const.bundleId, category: "SettingsView")

struct SettingsView: View {
    @Environment(\.modelContext) var modelContext

    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @AppStorage(Const.showNewInboxBadge) var showNewInboxBadge: Bool = true
    @AppStorage(Const.showFullscreenControls) var showFullscreenControls: Bool = true

    @AppStorage(Const.handleShortsDifferently) var handleShortsDifferently: Bool = false
    @AppStorage(Const.defaultShortsPlacement) var defaultShortsPlacement: VideoPlacement = .inbox
    @AppStorage(Const.hideShortsEverywhere) var hideShortsEverywhere: Bool = false
    @AppStorage(Const.shortsDetection) var shortsDetection: ShortsDetection = .safe
    @AppStorage(Const.hideMenuOnPlay) var hideMenuOnPlay: Bool = true

    @AppStorage(Const.videoAddedToInbox) var videoAddedToInbox: Bool = false
    @AppStorage(Const.videoAddedToQueue) var videoAddedToQueue: Bool = false

    @State var isExportingAll = false

    var body: some View {
        VStack {
            List {
                Section(header: Text("notifications"), footer: Text("notificationsHelper")) {
                    Toggle(isOn: $videoAddedToInbox) {
                        Text("videoAddedToInbox")
                    }

                    Toggle(isOn: $videoAddedToQueue) {
                        Text("videoAddedToQueue")
                    }
                }

                Section("videoSettings") {
                    Picker("newVideos", selection: $defaultVideoPlacement) {
                        ForEach(VideoPlacement.allCases.filter { $0 != .defaultPlacement }, id: \.self) {
                            Text($0.description(defaultPlacement: ""))
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: videoAddedToQueue) {
                        if videoAddedToQueue {
                            NotificationManager.askNotificationPermission()
                        }
                    }
                    .onChange(of: videoAddedToInbox) {
                        if videoAddedToInbox {
                            NotificationManager.askNotificationPermission()
                        }
                    }
                }

                Section(header: Text("playback")) {
                    Toggle(isOn: $showFullscreenControls) {
                        Text("showFullscreenControls")
                    }
                    Toggle(isOn: $hideMenuOnPlay) {
                        Text("hideMenuOnPlay")
                    }
                }

                Section(footer: Text("playbackHelper")) {
                    Toggle(isOn: $playVideoFullscreen) {
                        Text("startVideosInFullscreen")
                    }
                }

                Section(header: Text("shortsSettings"), footer: Text("shortsSettingsHelper")) {
                    Toggle(isOn: $handleShortsDifferently) {
                        Text("handleShortsDifferently")
                    }
                    Picker("shortsDetection", selection: $shortsDetection) {
                        ForEach(ShortsDetection.allCases, id: \.self) {
                            Text($0.description)
                        }
                    }
                    .disabled(!handleShortsDifferently)
                    Toggle(isOn: $hideShortsEverywhere) {
                        Text("hideShortsEverywhere")
                    }
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
                    Toggle(isOn: $showNewInboxBadge) {
                        Text("showNewInboxBadge")
                    }
                }

                if let url = UrlService.shareShortcutUrl {
                    Section("shareSheet") {
                        Link(destination: url) {
                            LibraryNavListItem("setupShareSheetAction", systemName: "square.and.arrow.up.on.square.fill")
                        }
                    }
                }

                Section("contact") {
                    Link(destination: UrlService.emailUrl) {
                        LibraryNavListItem("contactUs", systemName: Const.contactMailSF)
                    }
                }

                Section("userData") {
                    NavigationLink(value: LibraryDestination.importSubscriptions) {
                        Label("importSubscriptions", systemImage: "square.and.arrow.down.fill")
                    }
                    let feedUrls = AsyncSharableUrls(getUrls: exportAllSubscriptions, isLoading: $isExportingAll)
                    ShareLink(item: feedUrls, preview: SharePreview("exportSubscriptions")) {
                        if isExportingAll {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            LibraryNavListItem("exportSubscriptions", systemName: "square.and.arrow.up.fill")
                        }
                    }
                    NavigationLink(value: LibraryDestination.userData) {
                        Label("userData", systemImage: "opticaldiscdrive.fill")
                    }
                }

                NavigationLink(value: LibraryDestination.debug) {
                    Label("debug", systemImage: "ladybug.fill")
                }
            }
        }
        .navigationTitle("settings")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.teal)
    }

    func exportAllSubscriptions() async -> [(title: String, link: URL?)] {
        let container = modelContext.container
        let result = try? await SubscriptionService.getAllFeedUrls(container)
        return result ?? []
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
