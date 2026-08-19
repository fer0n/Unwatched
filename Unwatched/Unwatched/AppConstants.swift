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
        Const.customYoutubeApiKey: "",
        Const.allowOnMatch: false,
        Const.mergeSponsorBlockChapters: false,
        Const.youtubePremium: false,
        Const.sponsorSegmentSetting: SponsorBlockSegmentSetting.sponsorDefault.rawValue,
        Const.selfPromoSegmentSetting: SponsorBlockSegmentSetting.selfPromoDefault.rawValue

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
        Const.showClearQueueButton: true,
        Const.enableQueueContextMenu: false,
        Const.autoRefreshIgnoresSync: false,
        Const.useNoCookieUrl: false,

        // Playback
        Const.fullscreenControlsSetting: FullscreenControls.autoHide.rawValue,
        Const.preferPlayerType: false,
        Const.originalAudio: true,
        Const.backgroundPlayback: true,
        Const.hideMenuOnPlay: false,
        Const.returnToQueue: true,
        Const.rotateOnPlay: false,
        Const.temporarySpeedUp: Const.speedMax,
        Const.temporarySlowDown: Const.speedMin,
        Const.playVideoFullscreen: false,
        Const.disableCaptions: false,
        Const.autoCaptionsOnSeekBack: false,

        Const.swipeGestureUp: true,
        Const.swipeGestureDown: true,
        Const.swipeGestureLeft: true,
        Const.swipeGestureRight: true,

        Const.autoAirplayHD: false,
        Const.playBrowserVideosInApp: false,
        Const.surroundingEffect: true,

        // Appearance
        Const.browserDisplayMode: BrowserDisplayMode.inApp.rawValue,
        Const.showTabBarLabels: true,
        Const.showTabBarBadge: true,
        Const.hidePlayerPageIndicator: false,
        Const.videoListFormat: VideoListFormat.compact.rawValue,
        Const.inboxAppearance: InboxAppearance.cards.rawValue,
        Const.inboxOldestFirst: false,
        Const.lightModeTheme: AppAppearance.unwatched.rawValue,
        Const.darkModeTheme: AppAppearance.dark.rawValue,
        Const.themeColor: ThemeColor().rawValue,
        Const.lightAppIcon: false,

        // User Data
        Const.enableIcloudSync: false,
        Const.automaticBackups: true,
        Const.includeWatchHistoryInBackup: true,
        Const.includeUnimportantVideosInBackup: false,
        Const.autoDeleteBackups: true,
        Const.autoDeleteWatchedVideos: 0,
        Const.autoDeleteOrphanedVideos: 0,
        Const.autoDeleteInboxVideosLimit: 0,

        // Premium
        Const.unwatchedPremiumAcknowledged: false,
        Const.hidePremium: false
    ]
}
