//
//  LibraryDestination.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension View {
    // swiftlint:disable cyclomatic_complexity
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
                    }
                }
                #if os(macOS)
                .navigationStackWorkaround()
                #endif
            }
    }
    // swiftlint:enable cyclomatic_complexity
}

enum LibraryDestination: Codable {
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
         stats
}
