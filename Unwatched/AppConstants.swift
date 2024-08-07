//
//  App Constants.swift
//  Unwatched
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI

struct Const {
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

    static let highlightedPlaybackSpeeds = [1, 1.5, 2]
    static let speeds = [0.5, 1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2]
    static let previousChapterDelaySeconds: Double = 4

    // videos of new subscriptions being triaged
    static let triageNewSubs = 5
    static let minListEntriesToShowClear = 2
    static let autoRefreshIntervalSeconds: Double = 8 * 60

    static let earliestBackgroundBeginSeconds: Double = 30 * 60
    static let backgroundAppRefreshId = "com.pentlandFirth.Unwatched.refreshVideos"

    static let askForReviewPointThreashold = 30
    static let sheetOpacityValue = 0.6

    static let simultaneousNotificationsLimit = 3
    static let notificationImageUrl = "notificationImageUrl"
    static let notificationActionQueue = "notificationActionQueue"
    static let notificationActionClear = "notificationActionClear"
    static let notificationVideoId = "notificationVideoId"
    static let inboxVideoAddedCategory = "inboxVideoAddedCategory"
    static let queueVideoAddedCategory = "queueVideoAddedCategory"

    // MARK: - SF Symbols
    static let queueTopSF = "text.insert"

    static let refreshSF = "arrow.triangle.2.circlepath"
    static let queueTagSF = "rectangle.stack"
    static let inboxTabEmptySF = "tray"
    static let inboxTabFullSF = "tray.full"
    static let libraryTabSF = "books.vertical"

    static let settingsViewSF = "gearshape.fill"
    static let allVideosViewSF = "play.rectangle.on.rectangle"
    static let watchHistoryViewSF = "checkmark.circle"

    static let sideloadSF = "arrow.right.circle"

    static let filterSF = "line.3.horizontal.decrease.circle.fill"
    static let filterEmptySF = "line.3.horizontal.decrease.circle"
    static let addSF = "plus"

    static let watchedSF = "checkmark.circle.fill"
    static let clearSF = "xmark.circle.fill"
    static let clearNoFillSF = "xmark"

    static let alreadyInLibrarySF = "books.vertical.circle.fill"

    static let rateAppSF = "star.fill"
    static let contactMailSF = "envelope.fill"
    static let listItemChevronSF = "chevron.right"

    static let circleBackgroundSF = "circle.fill"
    static let checkmarkSF = "checkmark"

    static let videoDescriptionSF = "quote.bubble.fill"
    static let chaptersSF = "checklist.checked"

    static let appBrowserSF = "globe.desk.fill"

    static let nextChapterSF = "forward.end.fill"
    static let previousChapterSF = "backward.end.fill"
    static let nextVideoSF = "forward.end.alt.fill"

    static let enableFullscreenSF = "arrow.up.left.and.arrow.down.right"
    static let disableFullscreenSF = "arrow.down.right.and.arrow.up.left"

    // MARK: - AppStorage
    static let subscriptionSortOrder = "subscriptionSortOrder"
    static let playVideoFullscreen = "playVideoFullscreen"
    static let hideControlsFullscreen = "hideControlsFullscreen"
    static let goToQueueOnPlay = "goToQueueOnPlay"
    static let defaultVideoPlacement = "defaultVideoPlacement"
    static let playbackSpeed = "playbackSpeed"
    static let continuousPlay = "continuousPlay"
    static let refreshOnStartup = "refreshOnStartup"

    static let hideShortsEverywhere = "hideShortsEverywhere"
    static let shortsDetection = "shortsDetection"
    static let navigationManager = "NavigationManager"
    static let nowPlayingVideo = "nowPlayingVideo"
    static let lastAutoRefreshDate = "lastAutoRefreshDate"
    static let showTabBarLabels = "showTabBarLabels"
    static let requireClearConfirmation = "requireClearConfirmation"
    static let showClearQueueButton = "showClearQueueButton"

    static let automaticBackups = "automaticBackups"
    static let lastAutoBackupDate = "lastAutoBackupDate"
    static let minimalBackups = "minimalBackups"
    static let autoDeleteBackups = "autoDeleteBackups"

    static let shortcutHasBeenUsed = "shortcutHasBeenUsed"
    static let allVideosSortOrder = "allVideosSortOrder"
    static let sideloadingSortOrder = "sideloadingSortOrder"
    static let newInboxItemsCount = "newInboxItemsCount"
    static let newQueueItemsCount = "newQueueItemsCount"
    static let showTabBarBadge = "showTabBarBadge"
    static let enableIcloudSync = "enableIcloudSync"
    static let browserAsTab = "browserAsTab"

    static let selectedDetent = "selectedDetent"
    static let hideMenuOnPlay = "hideMenuOnPlay"

    static let videoAddedToInboxNotification = "videoAddedToInboxNotification"
    static let videoAddedToQueueNotification = "videoAddedToQueueNotification"
    static let monitorBackgroundFetchesNotification = "monitorBackgroundFetchesNotification"
    static let badgeCount = "badgeCount"
    static let showNotificationBadge = "showNotificationBadge"

    static let themeColor = "themeColor"
    static let showTutorial = "showTutorial"

    static let reloadVideoId = "reloadVideoId"
    static let sheetOpacity = "sheetOpacity"
    static let fullscreenControlsSetting = "fullscreenControlsSetting"
    static let refreshOnClose = "refreshOnClose"
}
