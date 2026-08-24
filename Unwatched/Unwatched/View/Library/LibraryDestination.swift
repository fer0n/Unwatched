//
//  LibraryDestination.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

extension View {
    // swiftlint:disable cyclomatic_complexity function_body_length
    func libraryDestination() -> some View {
        self
            .sendableSubscriptionDestination()
            .navigationDestination(for: LibraryDestination.self) { value in
                ZStack {
                    switch value {
                    case .allVideos:
                        AllVideosView()
                    case .watchHistory:
                        WatchHistoryView()
                    case .sideloading:
                        SideloadingView()
                    case .settings:
                        SettingsView()
                    case .userData:
                        UserDataSettingsView()
                    case .bookmarkedVideos:
                        BookmarkedVideosView()
                    case .importSubscriptions:
                        ImportSubscriptionsView(importButtonPadding: true)
                            .myNavigationTitle("importSubscriptions")
                    case .debug:
                        DebugView()
                    case .settingsNotifications:
                        NotificationSettingsView()
                    case .settingsNewVideos:
                        GeneralSettingsView()
                    case .settingsAppearance:
                        AppearanceSettingsView()
                    case .settingsPlayback:
                        PlaybackSettingsView()
                    case .settingsPlayerType:
                        PlayerTypeSettingsView()
                    case .settingsPodcastDownloads:
                        PodcastDownloadSettingsView()
                    case .help:
                        HelpView()
                    case .filter:
                        FilterSettingsView()
                    case .titleFilter:
                        GlobalTitleFilterWithPreview()
                    case .privacy:
                        PrivacySettingsView()
                    case .stats:
                        StatsView()
                    case .tag(let name):
                        TagDestinationView(name: name)
                    }
                }
                #if os(macOS)
                .navigationStackWorkaround()
                #endif
            }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}

enum LibraryDestination: Codable, Hashable {
    case sideloading,
         watchHistory,
         allVideos,
         bookmarkedVideos,
         userData,
         settings,
         settingsNotifications,
         settingsNewVideos,
         settingsAppearance,
         settingsPlayback,
         importSubscriptions,
         debug,
         help,
         filter,
         titleFilter,
         privacy,
         stats,
         settingsPlayerType,
         settingsPodcastDownloads,
         tag(String)
}

/// Resolves the name back to a row, so the navigation value stays Codable across a relaunch.
private struct TagDestinationView: View {
    @Query private var tags: [Tag]

    let name: String

    init(name: String) {
        self.name = name
        _tags = Query(filter: #Predicate<Tag> { $0.name == name })
    }

    var body: some View {
        if let tag = tags.first {
            TagVideosView(tag: tag)
        } else {
            ContentUnavailableView("noTagFound", systemImage: Const.filterTagSF)
        }
    }
}
