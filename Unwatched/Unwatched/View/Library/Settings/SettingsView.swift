//
//  SettingsView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct SettingsView: View {
    @Environment(\.modelContext) var modelContext
    @State var isExportingAll = false

    var body: some View {

        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                MySection("app") {
                    NavigationLink(value: LibraryDestination.settingsNotifications) {
                        Label("notifications", systemImage: "app.badge")
                    }

                    NavigationLink(value: LibraryDestination.settingsNewVideos) {
                        Label("videoSettings", systemImage: "film.stack")
                    }

                    NavigationLink(value: LibraryDestination.settingsPlayback) {
                        Label("playback", systemImage: "play.fill")
                    }

                    NavigationLink(value: LibraryDestination.settingsAppearance) {
                        Label("appearance", systemImage: "paintbrush.fill")
                    }
                }

                if let url = UrlService.shareShortcutUrl {
                    MySection("shareSheet") {
                        Link(destination: url) {
                            LibraryNavListItem(
                                "setupShareSheetAction",
                                systemName: "square.and.arrow.up.on.square.fill"
                            )
                        }
                    }
                }

                MySection("userData") {
                    NavigationLink(value: LibraryDestination.importSubscriptions) {
                        Label("importSubscriptions", systemImage: "square.and.arrow.down.fill")
                    }
                    let feedUrls = AsyncSharableUrls(
                        getUrls: exportAllSubscriptions,
                        isLoading: $isExportingAll
                    )
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

                MySection("sendFeedback") {
                    Link(destination: UrlService.writeReviewUrl) {
                        LibraryNavListItem("rateUnwatched", systemName: "star.fill")
                    }
                    NavigationLink(value: LibraryDestination.help) {
                        Label("emailAndFaq", systemImage: Const.contactMailSF)
                    }
                    Link(destination: UrlService.githubUrl) {
                        LibraryNavListItem("unwatchedOnGithub", imageName: "github-logo")
                    }
                    Link(destination: UrlService.mastodonUrl) {
                        LibraryNavListItem("unwatchedOnMastodon", imageName: "mastodon-logo")
                    }
                }

                NavigationLink(value: LibraryDestination.debug) {
                    Label("debug", systemImage: "ladybug.fill")
                }
                .listRowBackground(Color.insetBackgroundColor)

                Section {
                    VersionAndBuildNumber()
                }
                .listRowBackground(Color.backgroundColor)
            }
            .myNavigationTitle("settings")
        }
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
                    .tint(.neutralAccentColor)
                Text(label)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: Const.listItemChevronSF)
                    .tint(.neutralAccentColor)
            }
        }
        .accessibilityLabel(label)
    }
}

#Preview {
    SettingsView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
