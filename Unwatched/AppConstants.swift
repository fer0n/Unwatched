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
    static let backupType = UTType("com.pentlandFirth.unwatchedbackup")

    static let tapDestination = "tapDestination"

    // videos of new subscriptions being triaged
    static let triageNewSubs = 5
    static let minInboxEntriesToShowClear = 2
    static let autoRefreshIntervalSeconds: Double = 8 * 60

    static let earliestBackgroundBeginSeconds: Double = 40 * 60
    static let backgroundAppRefreshId = "com.pentlandFirth.Unwatched.refreshVideos"

    // MARK: - SF Symbols
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

    // MARK: - AppStorage
    static let subscriptionSortOrder = "subscriptionSortOrder"
    static let playVideoFullscreen = "playVideoFullscreen"
    static let goToQueueOnPlay = "goToQueueOnPlay"
    static let defaultVideoPlacement = "defaultVideoPlacement"
    static let playbackSpeed = "playbackSpeed"
    static let continuousPlay = "continuousPlay"
    static let refreshOnStartup = "refreshOnStartup"

    static let defaultShortsPlacement = "defaultShortsPlacement"
    static let handleShortsDifferently = "handleShortsDifferently"
    static let hideShortsEverywhere = "hideShortsEverywhere"
    static let shortsDetection = "shortsDetection"
    static let navigationManager = "NavigationManager"
    static let nowPlayingVideo = "nowPlayingVideo"
    static let lastAutoRefreshDate = "lastAutoRefreshDate"
    static let showTabBarLabels = "showTabBarLabels"
    static let requireClearConfirmation = "requireClearConfirmation"

    static let automaticBackups = "automaticBackups"
    static let lastAutoBackupDate = "lastAutoBackupDate"
    static let minimalBackups = "minimalBackups"

    static let shortcutHasBeenUsed = "shortcutHasBeenUsed"
    static let allVideosSortOrder = "allVideosSortOrder"
    static let hasNewInboxItems = "hasNewInboxItems"
    static let hasNewQueueItems = "hasNewQueueItems"
    static let showTabBarBadge = "showTabBarBadge"
    static let enableIcloudSync = "enableIcloudSync"
    static let showFullscreenControls = "showFullscreenControls"
    static let browserAsTab = "browserAsTab"

    static let selectedDetent = "selectedDetent"
    static let hideMenuOnPlay = "hideMenuOnPlay"

    static let videoAddedToInboxNotification = "videoAddedToInboxNotification"
    static let videoAddedToQueueNotification = "videoAddedToQueueNotification"
    static let monitorBackgroundFetchesNotification = "monitorBackgroundFetchesNotification"
    static let badgeCount = "badgeCount"
    static let showNotificationBadge = "showNotificationBadge"

    static let themeColor = "themeColor"
}
