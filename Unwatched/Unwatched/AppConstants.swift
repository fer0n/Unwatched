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
        Const.autoSkipRecurringChapters: true,
        Const.customYoutubeApiKey: "",
        Const.allowOnMatch: false,
        Const.mergeSponsorBlockChapters: false,
        Const.youtubePremium: false,
        Const.sponsorSegmentSetting: SponsorBlockSegmentSetting.sponsorDefault.rawValue,
        Const.selfPromoSegmentSetting: SponsorBlockSegmentSetting.selfPromoDefault.rawValue,

        // Queue
        Const.quickSwitchAllVideos: true,

        // Keep Media
        Const.autoDeleteWatchedVideos: 180,
        Const.autoDeleteOrphanedVideos: 30,
        Const.autoDeleteInboxVideosLimit: 100,

        // Premium
        // Lives in the key-value store, so it has to be registered here to be backed up at all.
        Const.unwatchedPremiumAcknowledged: false
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
        Const.trimSilence: false,
        Const.backgroundPlayback: true,
        Const.hideMenuOnPlay: true,
        Const.returnToQueue: true,
        Const.rotateOnPlay: false,
        Const.markWatchedOnEnded: true,
        Const.temporarySpeedUp: Const.speedMax,
        Const.temporarySlowDown: Const.speedMin,
        Const.playVideoFullscreen: false,
        Const.disableCaptions: false,
        Const.autoCaptionsOnSeekBack: false,
        Const.doubleTapSeekDuration: Const.seekSeconds,

        Const.swipeGestureUp: true,
        Const.swipeGestureDown: true,
        Const.swipeGestureLeft: true,
        Const.swipeGestureRight: true,

        Const.autoAirplayHD: false,
        Const.suggestVideos: false,
        Const.nativePlayerFallback: true,
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

        // Podcast downloads
        Const.podcastDownloadLimitHours: 0,
        Const.podcastDownloadKeepDays: 1,
        Const.podcastDownloadOnCellular: false,

        // Premium
        Const.hidePremium: false
    ]
}
