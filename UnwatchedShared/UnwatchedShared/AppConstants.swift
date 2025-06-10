//
//  App Constants.swift
//  Unwatched
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI

public struct Const {
    public static let mergeSponsorBlockChapters = "mergeSponsorBlockChapters"
    public static let youtubePremium = "youtubePremium"
    public static let skipSponsorSegments = "skipSponsorSegments"
    public static let skipChapterText = "skipChapterText"
    public static let filterVideoTitleText = "filterVideoTitleText"
    public static let nowPlayingVideo = "nowPlayingVideo"
    public static let enableIcloudSync = "enableIcloudSync"
    
    public static let inboxVideoAddedCategory = "inboxVideoAddedCategory"
    public static let queueVideoAddedCategory = "queueVideoAddedCategory"
    
    public static let themeColor = "themeColor"

    // MARK: - SF Symbols
    public static let watchedSF = "checkmark.circle.fill"
    public static let clearNoFillSF = "xmark"
    public static let checkmarkSF = "checkmark"
    public static let errorSF = "exclamationmark.triangle.fill"

    public static let bundleId = "com.pentlandFirth.Unwatched"

    public static let dotString = "•"
    public static let sensoryFeedback = SensoryFeedback.impact(intensity: 0.6)

    public static let playerAboveSheetHeight: CGFloat = 60
    public static let minSheetDetent: CGFloat = 50
    public static let playerControlPadding: CGFloat = 2
    public static let backupType = UTType("com.pentlandFirth.unwatchedbackup")
    
    public static let tapDestination = "tapDestination"
    public static let defaultVideoAspectRatio: Double = 16/9
    public static let videoAspectRatios: [Double] = [18/9, 4/3]
    public static let videoCornerRadius: CGFloat = 15
    public static let consideredWideAspectRatio: Double = 18/9
    public static let consideredTallAspectRatio: Double = 1
    public static let tallestAspectRatio: Double = 0.7
    public static let maxYtShortsDuration: Double = 60 * 3
    public static let aspectRatioTolerance: Double = 0.1
    public static let secondsConsideredCloseToEnd: CGFloat = 18
    public static let autoRefreshIgnoresSync = "autoRefreshIgnoresSync"
    public static let markAsWatched = "markAsWatched"
    public static let descriptionPopover = "descriptionPopover"
    
    /// When seeking to the end, the video will seek to duraiton - thisBuffer
    public static let seekToEndBuffer: CGFloat = 0.5
    
    /// Default seconds to seek forward/back
    public static let seekSeconds: Double = 10
    
    /// Update the current time if it differs by x seconds
    public static let updateTimeMinimum: Double = 10

    /// Playback speeds that will be spelled out
    public static let highlightedPlaybackSpeeds = [1, 1.5, 2, 3]

    /// Playback speeds that can savely shown at smaller sizes without line break
    public static let highlightedSpeedsInt = [1.0, 2.0, 3.0]
    public static let speeds = [0.4, 0.6, 0.8, 1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2, 2.2, 2.4, 2.6, 2.8, 3]
    public static let speedMin: Double = 0.4
    public static let speedMax: Double = 3

    /// The margin at which it will skip to the chapter start instead of the previous chapter
    public static let previousChapterDelaySeconds: Double = 4

    /// If current playback speed is bigger than this, it will temporarily increase, otherwise decrease
    public static let temporarySpeedSwap: Double = 1.6

    /// Number of videos from new subscriptions that will be triaged
    public static let triageNewSubs = 5
    public static let autoRefreshIntervalSeconds: Double = 10 * 60

    public static let earliestBackgroundBeginSeconds: Double = 30 * 60
    public static let backgroundAppRefreshId = "com.pentlandFirth.Unwatched.refreshVideos"

    public static let askForReviewPointThreshold = 20
    public static let sheetOpacityValue = 0.6

    /// Time difference within which it will be considered the same time between start/end of chapters
    public static let chapterTimeTolerance: Double = 2.0

    public static let playlistPageRequestLimit: Int = 25 // 25 * 50 videos per page/request -> 1250 videos

    public static let recentVideoDedupeCheck: Int = 30

    public static let updateDbTimeSeconds: Int = 30
    
    /// Timer interval to monitor the current playback
    public static let elapsedTimeMonitorSeconds: Double = 1

    /// Time in seconds before fullscreen controls are automatically hidden
    public static let controlsAutoHideDebounce: Double = 2.5

    /// Number of notifications that will be sent at once per inbox/queue
    public static let simultaneousNotificationsLimit = 1
    
    /// The maximum number of videos that will be shown in the inbox (performance reasons)
    /// Workaround, can be removed if @Query fetches in background or fixes performance
    public static let inboxFetchLimit = 200
    
    /// Option to keep the last x videos in the inbox when clearing it
    public static let inboxOverflowKeepCount = 20
    
    public static let notificationImageUrl = "notificationImageUrl"
    public static let notificationActionQueue = "notificationActionQueue"
    public static let notificationActionClear = "notificationActionClear"
    public static let notificationVideoId = "notificationVideoId"
    public static let addEntriesOnReceive = "addEntriesOnReceive"
    public static let shortcutItemPasteAndPlay = "PasteAndPlay"

    // MARK: - SF Symbols
    public static let queueTagSF = "rectangle.stack"
    public static let inboxTabEmptySF = "tray"
    public static let clearSF = "xmark.circle.fill"
    public static let removeNewSF = "circle.slash.fill"

    public static let queueTopSF = "text.insert"
    public static let queueBottomSF = "text.append"

    public static let refreshSF = "arrow.triangle.2.circlepath"
    public static let inboxTabFullSF = "tray.full"
    public static let libraryTabSF = "books.vertical"

    public static let settingsViewSF = "gearshape.fill"
    public static let allVideosViewSF = "square.stack.3d.down.forward.fill"
    public static let watchHistoryViewSF = "checkmark.circle"

    public static let sideloadSF = "arrow.right.circle"

    public static let filterSF = "line.3.horizontal.decrease.circle.fill"
    public static let filterEmptySF = "line.3.horizontal.decrease.circle"
    public static let addSF = "plus"

    public static let customPlaybackSpeedSF = "lock.fill"
    public static let customPlaybackSpeedOffSF = "lock.open.fill"

    public static let alreadyInLibrarySF = "books.vertical.circle.fill"

    public static let rateAppSF = "star.fill"
    public static let contactMailSF = "envelope.fill"
    public static let listItemChevronSF = "chevron.right"

    public static let circleBackgroundSF = "circle.fill"

    public static let videoDescriptionSF = "custom.line.3.text"
    public static let videoDescriptionCircleSF = "custom.line.3.text.circle.fill"
    public static let chaptersSF = "checklist.checked"

    public static let appBrowserSF = "play.rectangle.fill"

    public static let nextChapterSF = "chevron.right.2"
    public static let previousChapterSF = "chevron.left.2"
    public static let nextVideoSF = "forward.end.fill"
    public static let nextVideoCircleSF = "forward.end.circle.fill"
    public static let continuousPlaySF = "text.line.first.and.arrowtriangle.forward"

    public static let enableFullscreenSF = "arrow.up.left.and.arrow.down.right"
    public static let disableFullscreenSF = "arrow.down.right.and.arrow.up.left"

    public static let reloadSF = "arrow.clockwise"
    public static let reloadCircleSF = "arrow.clockwise.circle.fill"
    public static let shareSF = "square.and.arrow.up.fill"
    public static let videoSF = "play.rectangle.fill"
    public static let channelSF = "person.fill"
    
    // Settings
    public static let notificationsSettingsSF = "app.badge"
    public static let videoSettingsSF = "film.stack"
    public static let playbackSettingsSF = "play.fill"
    public static let filterSettingsSF = "line.3.horizontal.decrease"
    public static let appearanceSettingsSF = "paintbrush.fill"
    public static let userDataSettingsSF = "opticaldiscdrive.fill"
    public static let debugSettingsSF = "ladybug.fill"
    
    // Windows
    public static let windowHelp = "windowHelp"
    public static let windowImportSubs = "windowImportSubs"
    public static let windowBrowser = "windowBrowser"
    public static let mainWindowFrame = "mainWindowFrame"

    // MARK: - AppStorage
    public static let subscriptionSortOrder = "subscriptionSortOrder"
    public static let playVideoFullscreen = "playVideoFullscreen"
    public static let hideControlsFullscreen = "hideControlsFullscreen"
    public static let returnToQueue = "returnToQueue"
    public static let rotateOnPlay = "rotateOnPlay"
    public static let autoAirplayHD = "autoAirplayHD"
    public static let defaultVideoPlacement = "defaultVideoPlacement"
    public static let playbackSpeed = "playbackSpeed"
    public static let continuousPlay = "continuousPlay"
    public static let autoRefresh = "refreshOnStartup"
    public static let enableLogging = "enableLogging"
    public static let inboxFullDismissedDate = "inboxFullDismissedDate"

    
    /// Legacy setting, moved to `defaultShortsSetting`
    public static let hideShorts = "hideShortsEverywhere"
    public static let defaultShortsSetting = "defaultShortsSetting"
    
    public static let navigationManager = "NavigationManager"
    public static let playerManager = "PlayerManager"
    public static let lastAutoRefreshDate = "lastAutoRefreshDate"
    public static let showTabBarLabels = "showTabBarLabels"
    public static let requireClearConfirmation = "requireClearConfirmation"
    public static let showClearQueueButton = "showClearQueueButton"
    public static let showAddToQueueButton = "showAddToQueueButton"
    public static let useNoCookieUrl = "useNoCookieUrl"
    public static let enableQueueContextMenu = "enableQueueContextMenu"
    public static let disableCaptions = "disableCaptions"
    public static let minimalPlayerUI = "minimalPlayerUI"

    public static let automaticBackups = "automaticBackups"
    public static let lastAutoBackupDate = "lastAutoBackupDate"
    public static let minimalBackups = "minimalBackups"
    public static let exludeWatchHistoryInBackup = "exludeWatchHistoryInBackup"
    public static let autoDeleteBackups = "autoDeleteBackups"

    public static let shortcutHasBeenUsed = "shortcutHasBeenUsed"
    public static let sideloadingSortOrder = "sideloadingSortOrder"
    public static let showTabBarBadge = "showTabBarBadge"
    public static let browserAsTab = "browserAsTab"

    public static let selectedDetent = "selectedDetent"
    public static let hideMenuOnPlay = "hideMenuOnPlay"

    public static let videoAddedToInboxNotification = "videoAddedToInboxNotification"
    public static let videoAddedToQueueNotification = "videoAddedToQueueNotification"
    public static let monitorBackgroundFetchesNotification = "monitorBackgroundFetchesNotification"
    public static let showVideoListOrder = "showVideoListOrder"
    public static let badgeCount = "badgeCount"
    public static let showNotificationBadge = "showNotificationBadge"

    public static let lightModeTheme = "lightModeTheme"
    public static let darkModeTheme = "darkModeTheme"
    public static let showTutorial = "showTutorial"
    public static let lightAppIcon = "lightAppIcon"

    public static let reloadVideoId = "reloadVideoId"
    public static let sheetOpacity = "sheetOpacity"
    public static let fullscreenControlsSetting = "fullscreenControlsSetting"

    public static let videoListFormat = "videoListFormat"
    public static let hidePlayerPageIndicator = "hidePlayerPageIndicator"
}
