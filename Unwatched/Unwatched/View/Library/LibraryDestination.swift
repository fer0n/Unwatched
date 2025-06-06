//
//  LibraryDestination.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct LibraryDestinationModifier: ViewModifier {
    // swiftlint:disable cyclomatic_complexity
    func body(content: Content) -> some View {
        content
            .sendableSubscriptionDestination()
            .navigationDestination(for: LibraryDestination.self) { value in
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
                    BackupView()
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
                    VideoSettingsView()
                case .settingsAppearance:
                    AppearanceSettingsView()
                case .settingsPlayback:
                    PlaybackSettingsView()
                case .help:
                    HelpView()
                case .filter:
                    FilterSettingsView()
                }
            }
    }
    // swiftlint:enable cyclomatic_complexity
}

extension View {
    func libraryDestination() -> some View {
        self.modifier(LibraryDestinationModifier())
    }
}

enum LibraryDestination: Codable {
    case sideloading
    case watchHistory
    case allVideos
    case bookmarkedVideos
    case userData
    case settings
    case settingsNotifications
    case settingsNewVideos
    case settingsAppearance
    case settingsPlayback
    case importSubscriptions
    case debug
    case help
    case filter
}
