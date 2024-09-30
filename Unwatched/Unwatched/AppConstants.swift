//
//  App Constants.swift
//  Unwatched
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI
import UnwatchedShared

extension Const {
    static let bundleId = "com.pentlandFirth.Unwatched"

    static let dotString = "•"
    static let sensoryFeedback = SensoryFeedback.impact(intensity: 0.6)

    static let playerAboveSheetHeight: CGFloat = 60
    static let playerControlPadding: CGFloat = 2
    static let backupType = UTType("com.pentlandFirth.unwatchedbackup")

    static let tapDestination = "tapDestination"
    static let defaultVideoAspectRatio: Double = 16/9
    static let videoAspectRatios: [Double] = [18/9, 4/3]
    static let consideredWideAspectRatio: Double = 18/9
    static let consideredYtShortAspectRatio: Double = 1
    static let maxYtShortsDuration: Double = 60
    static let aspectRatioTolerance: Double = 0.1
    static let secondsConsideredCloseToEnd: CGFloat = 15

    /// Playback speeds that will be spelled out
    static let highlightedPlaybackSpeeds = [1, 1.5, 2]

    /// Playback speeds that can savely shown at smaller sizes without line break
    static let highlightedSpeedsInt = [1.0, 2.0]
    static let speeds = [0.5, 1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2, 3]

    /// The margin at which it will skip to the chapter start instead of the previous chapter
    static let previousChapterDelaySeconds: Double = 4

    /// If current playback speed is bigger than this, it will temporarily increase, otherwise decrease
    static let temporarySpeedSwap: Double = 1.6

    /// Number of videos from new subscriptions that will be triaged
    static let triageNewSubs = 5
    static let minListEntriesToShowClear = 2
    static let autoRefreshIntervalSeconds: Double = 10 * 60

    static let earliestBackgroundBeginSeconds: Double = 30 * 60
    static let backgroundAppRefreshId = "com.pentlandFirth.Unwatched.refreshVideos"

    static let askForReviewPointThreashold = 30
    static let sheetOpacityValue = 0.6

    /// Time difference within which it will be considered the same time between start/end of chapters
    static let chapterTimeTolerance: Double = 2.0

    static let playlistPageRequestLimit: Int = 25 // 25 * 50 videos per page/request -> 1250 videos

    static let recentVideoDedupeCheck: Int = 30

    static let updateDbTimeSeconds: Int = 30

    /// Time in seconds before fullscreen controls are automatically hidden
    static let controlsAutoHideDebounce: Double = 4

    /// Number of notifications that will be sent at once per inbox/queue
    static let simultaneousNotificationsLimit = 1
    static let notificationImageUrl = "notificationImageUrl"
    static let notificationActionQueue = "notificationActionQueue"
    static let notificationActionClear = "notificationActionClear"
    static let notificationVideoId = "notificationVideoId"

    // MARK: - SF Symbols
    static let queueTagSF = "rectangle.stack"
    static let inboxTabEmptySF = "tray"
    static let clearSF = "xmark.circle.fill"

    static let queueTopSF = "text.insert"
    static let queueBottomSF = "text.append"

    static let refreshSF = "arrow.triangle.2.circlepath"
    static let inboxTabFullSF = "tray.full"
    static let libraryTabSF = "books.vertical"

    static let settingsViewSF = "gearshape.fill"
    static let allVideosViewSF = "square.stack.3d.down.forward.fill"
    static let watchHistoryViewSF = "checkmark.circle"

    static let sideloadSF = "arrow.right.circle"

    static let filterSF = "line.3.horizontal.decrease.circle.fill"
    static let filterEmptySF = "line.3.horizontal.decrease.circle"
    static let addSF = "plus"

    static let customPlaybackSpeedSF = "lock.fill"

    static let alreadyInLibrarySF = "books.vertical.circle.fill"

    static let rateAppSF = "star.fill"
    static let contactMailSF = "envelope.fill"
    static let listItemChevronSF = "chevron.right"

    static let circleBackgroundSF = "circle.fill"

    static let videoDescriptionSF = "quote.bubble.fill"
    static let chaptersSF = "checklist.checked"

    static let appBrowserSF = "play.rectangle.fill"

    static let nextChapterSF = "forward.end.fill"
    static let previousChapterSF = "backward.end.fill"
    static let nextVideoSF = "forward.fill"
    static let continuousPlaySF = "text.line.first.and.arrowtriangle.forward"

    static let enableFullscreenSF = "arrow.up.left.and.arrow.down.right"
    static let disableFullscreenSF = "arrow.down.right.and.arrow.up.left"

    static let reloadSF = "arrow.circlepath"

    // MARK: - AppStorage
    static let subscriptionSortOrder = "subscriptionSortOrder"
    static let playVideoFullscreen = "playVideoFullscreen"
    static let hideControlsFullscreen = "hideControlsFullscreen"
    static let returnToQueue = "returnToQueue"
    static let rotateOnPlay = "rotateOnPlay"
    static let swapNextAndContinuous = "swapNextAndContinuous"
    static let defaultVideoPlacement = "defaultVideoPlacement"
    static let playbackSpeed = "playbackSpeed"
    static let continuousPlay = "continuousPlay"
    static let autoRefresh = "refreshOnStartup"

    static let hideShorts = "hideShortsEverywhere"
    static let navigationManager = "NavigationManager"
    static let lastAutoRefreshDate = "lastAutoRefreshDate"
    static let showTabBarLabels = "showTabBarLabels"
    static let requireClearConfirmation = "requireClearConfirmation"
    static let showClearQueueButton = "showClearQueueButton"
    static let showAddToQueueButton = "showAddToQueueButton"
    static let enableYtWatchHistory = "enableYtWatchHistory"
    static let enableQueueContextMenu = "enableQueueContextMenu"

    static let automaticBackups = "automaticBackups"
    static let lastAutoBackupDate = "lastAutoBackupDate"
    static let minimalBackups = "minimalBackups"
    static let exludeWatchHistoryInBackup = "exludeWatchHistoryInBackup"
    static let autoDeleteBackups = "autoDeleteBackups"

    static let shortcutHasBeenUsed = "shortcutHasBeenUsed"
    static let allVideosSortOrder = "allVideosSortOrder"
    static let sideloadingSortOrder = "sideloadingSortOrder"
    static let newInboxItemsCount = "newInboxItemsCount"
    static let newQueueItemsCount = "newQueueItemsCount"
    static let showTabBarBadge = "showTabBarBadge"
    static let browserAsTab = "browserAsTab"

    static let selectedDetent = "selectedDetent"
    static let hideMenuOnPlay = "hideMenuOnPlay"

    static let videoAddedToInboxNotification = "videoAddedToInboxNotification"
    static let videoAddedToQueueNotification = "videoAddedToQueueNotification"
    static let monitorBackgroundFetchesNotification = "monitorBackgroundFetchesNotification"
    static let badgeCount = "badgeCount"
    static let showNotificationBadge = "showNotificationBadge"

    static let lightModeTheme = "lightModeTheme"
    static let darkModeTheme = "darkModeTheme"
    static let showTutorial = "showTutorial"

    static let reloadVideoId = "reloadVideoId"
    static let sheetOpacity = "sheetOpacity"
    static let fullscreenControlsSetting = "fullscreenControlsSetting"

    static let videoListFormat = "videoListFormat"
}

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
        Const.themeColor: ThemeColor(),
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
