//
//  SettingsView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct SettingsView: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                MySection("app") {
                    NavigationLink(value: LibraryDestination.settingsNotifications) {
                        Label("notifications", systemImage: Const.notificationsSettingsSF)
                    }

                    NavigationLink(value: LibraryDestination.settingsNewVideos) {
                        Label("videoSettings", systemImage: Const.videoSettingsSF)
                    }

                    NavigationLink(value: LibraryDestination.settingsPlayback) {
                        Label("playback", systemImage: Const.playbackSettingsSF)
                    }

                    NavigationLink(value: LibraryDestination.filter) {
                        Label("filterSettings", systemImage: Const.filterSettingsSF)
                    }

                    NavigationLink(value: LibraryDestination.settingsAppearance) {
                        Label("appearance", systemImage: Const.appearanceSettingsSF)
                    }
                }

                MySection("shortcuts") {
                    Link(destination: UrlService.shareShortcutUrl) {
                        LibraryNavListItem(
                            "setupShareSheetAction",
                            systemName: "square.and.arrow.up.on.square.fill"
                        )
                    }
                    Link(destination: UrlService.generateChaptersShortcutUrl) {
                        LibraryNavListItem(
                            "generateChaptersShortcut",
                            systemName: "checklist"
                        )
                    }
                }

                MySection("userData") {
                    NavigationLink(value: LibraryDestination.importSubscriptions) {
                        Label("importSubscriptions", systemImage: "square.and.arrow.down.fill")
                    }
                    ExportSubscriptionsShareLink {
                        LibraryNavListItem("exportSubscriptions", systemName: "square.and.arrow.up.fill")
                    }
                    NavigationLink(value: LibraryDestination.userData) {
                        Label("userData", systemImage: Const.userDataSettingsSF)
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
                    Link(destination: UrlService.blueskyUrl) {
                        LibraryNavListItem("unwatchedOnBluesky", imageName: "bluesky_logo")
                    }
                }

                Section {
                    ZStack {
                        UserTipsView()
                            .padding(.top)
                    }
                }
                .listRowBackground(theme.color.mix(with: .black, by: 0.4))
                .listRowInsets(EdgeInsets())
                .foregroundStyle(theme.darkContrastColor)

                NavigationLink(value: LibraryDestination.debug) {
                    Label("debug", systemImage: Const.debugSettingsSF)
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
}

#Preview {
    SettingsView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager())
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
