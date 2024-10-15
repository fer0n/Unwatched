//
//  App Constants.swift
//  Unwatched
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI
import UnwatchedShared

extension Const {
    static let settingsDefaults: [String: Sendable] = [
        // Notifications
        Const.videoAddedToInboxNotification: false,
        Const.videoAddedToQueueNotification: false,
        Const.showNotificationBadge: false,

        // Videos
        Const.defaultVideoPlacement: VideoPlacement.inbox.rawValue,
        Const.hideShorts: false,
        Const.requireClearConfirmation: true,
        Const.showClearQueueButton: true,
        Const.showAddToQueueButton: false,
        Const.mergeSponsorBlockChapters: false,
        Const.enableYtWatchHistory: true,
        Const.autoRefresh: true,
        Const.enableQueueContextMenu: false,

        // Playback
        Const.fullscreenControlsSetting: FullscreenControls.autoHide.rawValue,
        Const.hideMenuOnPlay: true,
        Const.playVideoFullscreen: false,
        Const.returnToQueue: false,
        Const.rotateOnPlay: false,
        Const.swapNextAndContinuous: false,

        // Appearance
        Const.showTabBarLabels: true,
        Const.showTabBarBadge: true,
        Const.themeColor: ThemeColor().rawValue,
        Const.browserAsTab: false,
        Const.sheetOpacity: false,
        Const.lightModeTheme: AppAppearance.unwatched.rawValue,
        Const.darkModeTheme: AppAppearance.dark.rawValue,
        Const.videoListFormat: VideoListFormat.compact.rawValue,

        // User Data
        Const.automaticBackups: true,
        Const.minimalBackups: true,
        Const.enableIcloudSync: false,
        Const.exludeWatchHistoryInBackup: false,

        // Other Things
        Const.playbackSpeed: 1
    ]
}
