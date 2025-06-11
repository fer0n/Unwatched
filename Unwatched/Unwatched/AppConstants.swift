//
//  App Constants.swift
//  Unwatched
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI
import UnwatchedShared

extension Const {
    static let syncedSettingsDefaults: [String: Sendable] = [
        // Filter
        Const.defaultShortsSetting: ShortsSetting.defaultSetting.rawValue,
        Const.skipChapterText: "",
        Const.mergeSponsorBlockChapters: false,
        Const.youtubePremium: false,
        Const.skipSponsorSegments: false
    ]

    static let settingsDefaults: [String: Sendable] = [
        // Notifications
        Const.videoAddedToInboxNotification: false,
        Const.videoAddedToQueueNotification: false,
        Const.showNotificationBadge: false,

        // Videos
        Const.defaultVideoPlacement: VideoPlacement.inbox.rawValue,
        Const.autoRefresh: true,
        Const.requireClearConfirmation: true,
        Const.showAddToQueueButton: false,
        Const.showClearQueueButton: true,
        Const.enableQueueContextMenu: false,
        Const.autoRefreshIgnoresSync: false,
        Const.useNoCookieUrl: false,

        // Playback
        Const.fullscreenControlsSetting: FullscreenControls.autoHide.rawValue,
        Const.hideMenuOnPlay: true,
        Const.returnToQueue: false,
        Const.rotateOnPlay: false,
        Const.playVideoFullscreen: false,
        Const.disableCaptions: false,
        Const.minimalPlayerUI: false,
        Const.autoAirplayHD: false,

        // Appearance
        Const.browserAsTab: false,
        Const.showTabBarLabels: true,
        Const.showTabBarBadge: true,
        Const.sheetOpacity: false,
        Const.hidePlayerPageIndicator: false,
        Const.videoListFormat: VideoListFormat.compact.rawValue,
        Const.lightModeTheme: AppAppearance.unwatched.rawValue,
        Const.darkModeTheme: AppAppearance.dark.rawValue,
        Const.themeColor: ThemeColor().rawValue,
        Const.lightAppIcon: false,

        // User Data
        Const.enableIcloudSync: false,
        Const.automaticBackups: true,
        Const.exludeWatchHistoryInBackup: false,
        Const.minimalBackups: true,
        Const.autoDeleteBackups: false
    ]
}
