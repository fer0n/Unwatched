//
//  SettingsView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct SettingsView: View {
    @Environment(NavigationManager.self) var navManager
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @State private var showOpmlImporter = false

    var body: some View {
        ZStack {
            MyBackgroundColor(macOS: false)

            MyForm {
                MySection {
                    PremiumNavListItem()
                }

                MySection("app") {
                    NavigationLink(value: LibraryDestination.settingsNewVideos) {
                        Label("generalSettings", systemImage: Const.settingsViewSF)
                    }

                    NavigationLink(value: LibraryDestination.settingsPlayback) {
                        Label("playback", systemImage: Const.playbackSettingsSF)
                    }

                    NavigationLink(value: LibraryDestination.settingsPodcastDownloads) {
                        Label("podcastDownloads", systemImage: Const.downloadedSF)
                    }

                    NavigationLink(value: LibraryDestination.settingsNotifications) {
                        Label("notifications", systemImage: Const.notificationsSettingsSF)
                    }

                    NavigationLink(value: LibraryDestination.filter) {
                        Label("filterSettings", systemImage: Const.filterSettingsSF)
                    }

                    NavigationLink(value: LibraryDestination.settingsAppearance) {
                        Label("appearance", systemImage: Const.appearanceSettingsSF)
                    }
                }

                MySection("shortcuts") {
                    CloudAiButton {
                        LibraryNavListItem(
                            "generateChapters",
                            systemName: "sparkles"
                        )
                    }
                    .requiresPremium()
                }

                MySection("userData") {
                    YoutubeLoginButton()

                    Menu {
                        Button("importFromYoutube") {
                            navManager.presentedLibrary.append(LibraryDestination.importSubscriptions)
                        }
                        Button {
                            showOpmlImporter = true
                        } label: {
                            Text(verbatim: "OPML")
                        }
                    } label: {
                        LibraryNavListItem("importSubscriptions", systemName: "square.and.arrow.down.fill")
                    }
                    .settingsListRow()
                    ExportSubscriptionsShareLink {
                        LibraryNavListItem("exportSubscriptions", systemName: "square.and.arrow.up.fill")
                    }
                    NavigationLink(value: LibraryDestination.userData) {
                        Label("userData", systemImage: Const.userDataSettingsSF)
                    }
                    NavigationLink(value: LibraryDestination.privacy) {
                        Label("privacyPolicy", systemImage: "checkmark.shield.fill")
                    }
                }

                MySection("sendFeedback") {
                    Link(destination: UrlService.writeReviewUrl) {
                        LibraryNavListItem("rateUnwatched", systemName: "star.fill")
                    }
                    .settingsListRow()
                    NavigationLink(value: LibraryDestination.help) {
                        Label("emailAndFaq", systemImage: Const.contactMailSF)
                    }
                    Link(destination: UrlService.githubUrl) {
                        LibraryNavListItem("unwatchedOnGithub", imageName: "github-logo")
                    }
                    .settingsListRow()
                    Link(destination: UrlService.mastodonUrl) {
                        LibraryNavListItem("unwatchedOnMastodon", imageName: "mastodon-logo")
                    }
                    .settingsListRow()
                    Link(destination: UrlService.blueskyUrl) {
                        LibraryNavListItem("unwatchedOnBluesky", imageName: "bluesky_logo")
                    }
                    .settingsListRow()
                }

                MySection {
                    Link(destination: UrlService.releasesUrl) {
                        LibraryNavListItem(
                            "releases",
                            systemName: "sparkles.2"
                        )
                    }
                    .settingsListRow()
                    Link(destination: UrlService.testFlightUrl) {
                        LibraryNavListItem(
                            "testFlight",
                            systemName: "airplane.departure"
                        )
                    }
                    .settingsListRow()
                    .contextMenu {
                        Button {
                            ClipboardService.set(UrlService.testFlightUrl.absoluteString)
                        } label: {
                            Label("copyUrl", systemImage: "document.on.document.fill")
                        }
                    }
                }
                .myListInsetBackground()

                Section {
                    ZStack {
                        UserTipsView()
                            .padding(.top)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(theme.color.mix(with: .black, by: 0.4))
                .foregroundStyle(theme.darkContrastColor)

                NavigationLink(value: LibraryDestination.debug) {
                    Label("debug", systemImage: Const.debugSettingsSF)
                }
                .myListInsetBackground()

                Section {
                    VersionAndBuildNumber()
                }
                .myListRowBackground()
            }
            .myNavigationTitle("settings")
            .myTint()
            .fileImporter(
                isPresented: $showOpmlImporter,
                allowedContentTypes: [.opml, .xml],
                onCompletion: handleOpmlImport
            )
        }
    }
}

extension SettingsView {
    func handleOpmlImport(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            navManager.presentedLibrary.append(LibraryDestination.importOpml(url))
        case .failure(let error):
            Log.info("\(error.localizedDescription)")
        }
    }
}

extension View {
    /// visionOS gives a `Link` or `Menu` in a list its own button chrome, which indents the row past
    /// the plain rows next to it, and its own hover effect instead of the row-wide highlight.
    func settingsListRow() -> some View {
        self
            #if os(visionOS)
            .buttonStyle(.plain)
            .hoverEffectDisabled()
            .listRowHoverEffect(.highlight)
        #endif
    }
}

#Preview {
    SettingsView()
        .previewEnvironments()
}
