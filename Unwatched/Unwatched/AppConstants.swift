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
        Const.allowOnMatch: false,
        Const.mergeSponsorBlockChapters: false,
        Const.youtubePremium: false,
        Const.skipSponsorSegments: false

    ]

    static let settingsDefaults: [String: Sendable] = [
        // Notifications
        Const.videoAddedToInboxNotification: false,
        Const.videoAddedToQueueNotification: false,
        Const.showNotificationBadge: false,

        // General
        Const.defaultVideoPlacement: VideoPlacement.inbox.rawValue,
        Const.autoClearNew: false,
        Const.autoRefresh: true,
        Const.requireClearConfirmation: true,
        Const.showAddToQueueButton: false,
        Const.showClearQueueButton: true,
        Const.enableQueueContextMenu: false,
        Const.autoRefreshIgnoresSync: false,
        Const.useNoCookieUrl: false,

        // Playback
        Const.fullscreenControlsSetting: FullscreenControls.autoHide.rawValue,
        Const.originalAudio: true,
        Const.backgroundPlayback: true,
        Const.hideMenuOnPlay: true,
        Const.returnToQueue: false,
        Const.rotateOnPlay: false,
        Const.temporarySpeedUp: Const.speedMax,
        Const.temporarySlowDown: Const.speedMin,
        Const.playVideoFullscreen: false,
        Const.disableCaptions: false,
        Const.minimalPlayerUI: false,

        Const.swipeGestureUp: true,
        Const.swipeGestureDown: true,
        Const.swipeGestureLeft: true,
        Const.swipeGestureRight: true,

        Const.autoAirplayHD: false,
        Const.playBrowserVideosInApp: false,
        Const.surroundingEffect: true,

        // Appearance
        Const.browserAsTab: false,
        Const.showTabBarLabels: true,
        Const.showTabBarBadge: true,
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
        Const.autoDeleteBackups: false,

        // Premium
        Const.unwatchedPremiumAcknowledged: false,
        Const.hidePremium: false
    ]
}
