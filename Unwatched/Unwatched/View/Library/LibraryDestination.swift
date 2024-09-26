//
//  LibraryDestination.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct LibraryDestinationModifier: ViewModifier {
    @Environment(\.modelContext) var modelContext

    // swiftlint:disable cyclomatic_complexity
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
            .navigationDestination(for: SendableSubscription.self) { sub in
                SendableSubscriptionDetailView(sub, modelContext)
            }
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

enum LibraryDestination {
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
}
