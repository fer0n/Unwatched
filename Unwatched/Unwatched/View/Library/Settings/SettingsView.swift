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

                    NavigationLink(value: LibraryDestination.settingsNotifications) {
                        Label("notifications", systemImage: Const.notificationsSettingsSF)
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
                    .linkHoverEffect()

                    Link(destination: UrlService.generateChaptersShortcutUrl) {
                        LibraryNavListItem(
                            "generateChapters",
                            systemName: "sparkles"
                        )
                    }
                    .requiresPremium()
                    .linkHoverEffect()
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
                    NavigationLink(value: LibraryDestination.privacy) {
                        Label("privacyPolicy", systemImage: "checkmark.shield.fill")
                    }
                }

                MySection("sendFeedback") {
                    Link(destination: UrlService.writeReviewUrl) {
                        LibraryNavListItem("rateUnwatched", systemName: "star.fill")
                    }
                    .linkHoverEffect()
                    NavigationLink(value: LibraryDestination.help) {
                        Label("emailAndFaq", systemImage: Const.contactMailSF)
                    }
                    Link(destination: UrlService.githubUrl) {
                        LibraryNavListItem("unwatchedOnGithub", imageName: "github-logo")
                    }
                    .linkHoverEffect()
                    Link(destination: UrlService.mastodonUrl) {
                        LibraryNavListItem("unwatchedOnMastodon", imageName: "mastodon-logo")
                    }
                    .linkHoverEffect()
                    Link(destination: UrlService.blueskyUrl) {
                        LibraryNavListItem("unwatchedOnBluesky", imageName: "bluesky_logo")
                    }
                    .linkHoverEffect()
                }

                MySection {
                    Link(destination: UrlService.releasesUrl) {
                        LibraryNavListItem(
                            "releases",
                            systemName: "sparkles.2"
                        )
                    }
                    .linkHoverEffect()
                }
                .myListInsetBackground()

                Section {
                    ZStack {
                        UserTipsView()
                            .padding(.top)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(theme.color.myMix(with: .black, by: 0.4))
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
        }
    }
}

extension View {
    func linkHoverEffect() -> some View {
        self
            #if os(visionOS)
            .hoverEffectDisabled()
            .listRowHoverEffect(.highlight)
        #endif
    }
}

#Preview {
    SettingsView()
        .previewEnvironments()
}
