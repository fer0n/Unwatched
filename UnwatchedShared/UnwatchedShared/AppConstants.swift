//
//  App Constants.swift
//  Unwatched
//

import CoreMedia
import Foundation
import UniformTypeIdentifiers
import SwiftUI

public struct Const {
    public static let mergeSponsorBlockChapters = "mergeSponsorBlockChapters"
    public static let youtubePremium = "youtubePremium"
    public static let unwatchedPremiumAcknowledged = "unwatchedPremiumAcknowledged"
    public static let hidePremium = "hidePremium"
    /// Legacy on/off skip toggle, folded into `sponsorSegmentSetting`
    /// (see `SponsorBlockSegmentSetting.migrateSkipSponsorSegmentsIfNeeded`)
    public static let skipSponsorSegments = "skipSponsorSegments"
    public static let sponsorSegmentSetting = "sponsorSegmentSetting"
    public static let selfPromoSegmentSetting = "selfPromoSegmentSetting"
    public static let skipChapterText = "skipChapterText"
    public static let customYoutubeApiKey = "customYoutubeApiKey"
    public static let filterVideoTitleText = "filterVideoTitleText"
    public static let allowOnMatch = "allowOnMatch"
    public static let nowPlayingVideo = "nowPlayingVideo"
    public static let enableIcloudSync = "enableIcloudSync"
    public static let requiresDurationFetch = "requiresDurationFetch"
    public static let didPurgeDerivableChapters = "didPurgeDerivableChapters"

    public static let inboxVideoAddedCategory = "inboxVideoAddedCategory"
    public static let queueVideoAddedCategory = "queueVideoAddedCategory"

    public static let themeColor = "themeColor"

    // MARK: - SF Symbols
    public static let watchedSF = "checkmark.circle.fill"
    public static let clearNoFillSF = "xmark"
    public static let checkmarkSF = "checkmark"
    public static let errorSF = "exclamationmark.triangle.fill"
    public static let copySF = "document.on.document.fill"

    public static let bundleId = "com.pentlandFirth.Unwatched"

    public static let dotString = "•"
    public static let sensoryFeedback = SensoryFeedback.impact(intensity: 0.6)
    public static let deniedFeedback = SensoryFeedback.error

    public static let playerAboveSheetHeight: CGFloat = 75
    public static let minSheetDetent: CGFloat = 75
    public static let backupType = UTType("com.pentlandFirth.unwatchedbackup")

    /// Legacy (pre-compression) backups recompressed per automatic auto-delete run, to avoid a
    /// large burst of iCloud downloads all at once; the manual "Auto Delete Backups Now" button
    /// has no limit, since the user is already waiting on it.
    public static let autoRecompressBackupLimit = 10

    /// Max video IDs supported by a single YouTube API request
    public static let maxVideoIdsPerRequest = 50
    public static let tapDestination = "tapDestination"
    public static let defaultVideoAspectRatio: Double = 16/9

    /// Longest edge, in pixels, that a cached thumbnail/cover is decoded at.
    public static let maxDecodedImagePixelSize: CGFloat = 1200
    public static let videoAspectRatios: [Double] = [18/9, 4/3]
    
    /// Video thumbnail list item corner radius
    public static let videoCornerRadius: CGFloat = 15
    
    ///
    public static let videoPlayerCornerRadius: CGFloat = 9
    
    public static let consideredWideAspectRatio: Double = 18/9
    public static let consideredTallAspectRatio: Double = 1
    public static let maxYtShortsDuration: Double = 60 * 3
    public static let aspectRatioTolerance: Double = 0.1
    public static let secondsConsideredCloseToEnd: CGFloat = 18
    public static let autoRefreshIgnoresSync = "autoRefreshIgnoresSync"
    public static let markAsWatched = "markAsWatched"
    public static let tvPlaybackMode = "tvPlaybackMode"
    public static let descriptionPopover = "descriptionPopover"

    /// Cooldown period before fetching the duration again (might happen sooner if batched with other requests)
    public static let durationFetchInterval: Double = 12 * 60 * 60 // 10 hours
    
    /// When seeking to the end, the video will seek to duraiton - thisBuffer
    public static let seekToEndBuffer: CGFloat = 0.5

    /// Default seconds to seek forward/back
    public static let seekSeconds: Double = 10

    /// Update the current time if it differs by x seconds
    public static let updateTimeMinimum: Double = 10

    public static let speeds = [
        0.2,
        0.3,
        0.4,
        0.5,
        0.6,
        0.7,
        0.8,
        0.9,
        1,
        1.1,
        1.2,
        1.3,
        1.4,
        1.5,
        1.6,
        1.7,
        1.8,
        1.9,
        2,
        2.1,
        2.2,
        2.3,
        2.4,
        2.5,
        2.6,
        2.7,
        2.8,
        2.9,
        3
    ]
    public static let speedMin: Double = 0.6
    public static let speedMax: Double = 2

    /// The margin at which it will skip to the chapter start instead of the previous chapter
    public static let previousChapterDelaySeconds: Double = 4

    /// If current playback speed is bigger than this, it will temporarily increase, otherwise decrease
    public static let temporarySpeedSwap: Double = 1.6

    /// Number of videos from new subscriptions that will be triaged
    public static let triageNewSubs = 5

    /// Same for subscriptions added during onboarding, lower so a first inbox stays skimmable
    public static let triageOnboardingSubs = 3

    /// Episodes kept from a podcast feed.
    public static let podcastEpisodeLimit = 50

    /// Hours of queue that can be kept downloaded; 0 is off, -1 unlimited
    public static let podcastDownloadHourOptions = [0, 5, 10, 50, 100, -1]
    public static let podcastDownloadKeepDayOptions = [0, 1, 7]

    public static let podcastDownloadSessionId = bundleId + ".podcastDownloads"

    // "Trim silence" shortens each pause in the composition the episode plays from, rather than running the player
    // faster through it.

    /// How much of a pause at either end is left at its original length.
    public static let silenceGuardBand: Double = 0.15

    /// Shortest a pause is allowed to become, and the share of itself a longer one keeps — a long pause cut to the
    /// same length as a short one loses the beat the speaker put there.
    public static let silenceTargetPause: Double = 0.4
    public static let silenceKeepFraction: Double = 0.35
    /// What has to be left between the guard bands, so a scaled range never rounds away to nothing.
    public static let silenceMinimumInterior: Double = 0.05

    /// Shortest run of quiet that counts as a pause, and the least it has to save to be worth a segment in the
    /// composition.
    public static let silenceMinimumPause: Double = 0.4
    public static let silenceMinimumSaving: Double = 0.15

    /// Bumped whenever a change would make a stored scan's pause list wrong to reuse — a lower detection floor, a
    /// different threshold.
    public static let silenceScanVersion = 2

    /// Range the scan's own threshold is held to, in dBFS, in case an episode's levels have only one hump for Otsu's
    /// method to split (see `SilenceScanner.silenceThreshold`).
    public static let silenceThresholdFloorDb: Double = -60
    public static let silenceThresholdCeilingDb: Double = -30

    /// Fine enough that a boundary lands on a sample rather than on a 600th of a second.
    public static let silenceTimescale: CMTimeScale = 44_100

    public static let autoRefreshIntervalSeconds: Double = 10 * 60

    /// Share of subscriptions whose feed fetch has to fail in the same refresh before the reload button shows its
    /// failed state.
    public static let refreshFailedThreshold: Double = 0.5

    /// Consecutive failed refreshes before a feed is flagged to the user, see `SubscriptionData.hasFeedIssue`.
    public static let subscriptionFailureThreshold = 3

    public static let earliestBackgroundBeginSeconds: Double = 30 * 60
    public static let backgroundAppRefreshId = "com.pentlandFirth.Unwatched.refreshVideos"

    public static let askForReviewPointThreshold = 20
    public static let askForReviewMaxCount = 2
    public static let sheetOpacityValue = 0.6

    /// Time difference within which it will be considered the same time between start/end of chapters
    public static let chapterTimeTolerance: Double = 2.0

    public static let playlistPageRequestLimit: Int = 25 // 25 * 50 videos per page/request -> 1250 videos

    public static let recentVideoDedupeCheck: Int = 30

    /// How often playback is sampled for watch-time stats. Kept short so a sample can't span a
    /// long stall; the samples are accumulated in memory and only written out on `flush`.
    public static let updateDbTimeSeconds: Int = 30

    /// How often the elapsed time is written to the database while playing. Pause, video change
    /// and backgrounding all persist it too, so this only bounds what a crash or a jetsam kill
    /// during uninterrupted (usually background) playback can lose.
    public static let elapsedTimePersistSeconds: Int = 120

    /// Safety flush for accumulated watch time when playback never pauses
    public static let statsFlushIntervalSeconds: Double = 600

    /// Timer interval to monitor the current playback
    public static let elapsedTimeMonitorSeconds: Double = 1

    /// Time in seconds before fullscreen controls are automatically hidden
    public static let controlsAutoHideDebounce: Double = 2.5

    /// Time in seconds before the scrubber is hidden after a seek (shorter than the
    /// regular controls debounce so it disappears quickly once seeking stops)
    public static let seekScrubberAutoHideDebounce: Double = 0.75

    /// Number of notifications that will be sent at once per inbox/queue
    public static let simultaneousNotificationsLimit = 1

    /// The maximum number of videos that will be shown in the inbox (performance reasons)
    /// Workaround, can be removed if @Query fetches in background or fixes performance
    public static let inboxFetchLimit = 200

    /// The maximum number of videos shown in the queue before a "show all" button appears
    public static let queueFetchLimit = 200

    /// Option to keep the last x videos in the inbox when clearing it
    public static let inboxOverflowKeepCount = 20
    public static let inboxOverflowKeepCountAlt = 50
    
    /// Days after which cached images will be cleaned up
    public static let cleanupCacheDays = 40

    public static let notificationImageUrl = "notificationImageUrl"
    public static let notificationActionQueue = "notificationActionQueue"
    public static let notificationActionClear = "notificationActionClear"
    public static let notificationVideoId = "notificationVideoId"
    public static let addEntriesOnReceive = "addEntriesOnReceive"
    public static let shortcutItemPasteAndPlay = "PasteAndPlay"
    public static let shortcutItemPasteAndQueue = "PasteAndQueue"
    public static let shortcutItemSearchYoutube = "SearchYoutube"

    // MARK: - SF Symbols
    public static let queueTagSF = "rectangle.stack"
    public static let filterTagSF = "line.3.horizontal.decrease"
    public static let untaggedSF = "tag.slash.fill"
    public static let inboxTabEmptySF = "tray"
    public static let clearSF = "xmark.circle.fill"
    public static let removeNewSF = "circle.slash.fill"

    public static let queueNextSF = "text.insert"
    public static let queueLastSF = "text.append"

    public static let refreshSF = "arrow.triangle.2.circlepath"
    public static let refreshFailedSF = "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
    public static let inboxTabFullSF = "tray.full"
    public static let libraryTabSF = "books.vertical"

    public static let settingsViewSF = "gearshape.fill"
    public static let allVideosViewSF = "square.stack.3d.down.forward.fill"
    public static let watchHistoryViewSF = "checkmark.circle"
    public static let premiumIndicatorSF = "star.circle.fill"

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

    public static let youtubeSF = "play.rectangle.fill"
    public static let podcastSF = "waveform"
    public static let downloadedSF = "arrow.down"
    public static let viewOnYouTubeSF = "arrow.up.right"

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
    public static let channelSF = "person.fill"

    // Settings
    public static let notificationsSettingsSF = "app.badge"
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
    public static let preFakePipWindowFrame = "preFakePipWindowFrame"
    public static let fakePipWindowFrame = "fakePipWindowFrame"
    public static let isFakePip = "isFakePip"
    public static let windowPremium = "windowPremium"

    // MARK: - AppStorage
    public static let subscriptionSortOrder = "subscriptionSortOrder"
    public static let playVideoFullscreen = "playVideoFullscreen"
    public static let backgroundPlayback = "backgroundPlayback"
    public static let hideControlsFullscreen = "hideControlsFullscreen"
    public static let surroundingEffect = "surroundingEffect"
    public static let returnToQueue = "returnToQueue"
    public static let rotateOnPlay = "rotateOnPlay"
    public static let autoAirplayHD = "autoAirplayHD"
    public static let defaultVideoPlacement = "defaultVideoPlacement"
    public static let autoClearNew = "autoClearNew"
    public static let playbackSpeed = "playbackSpeed"
    public static let continuousPlay = "continuousPlay"
    public static let suggestVideos = "suggestVideos"
    public static let autoRefresh = "refreshOnStartup"
    public static let enableLogging = "enableLogging"
    public static let originalAudio = "originalAudio"
    public static let trimSilence = "trimSilence"
    public static let trimSilenceTier = "trimSilenceTier"
    /// Running total of seconds trimmed, added up as they're played rather than as episodes are
    /// scanned (see `accumulateSecondsSaved`) — never reset, since it's meant to answer "how much
    /// has this saved me" over the setting's whole lifetime, not for one episode or session.
    public static let trimSilenceSecondsSaved = "trimSilenceSecondsSaved"
    public static let playBrowserVideosInApp = "playBrowserVideosInApp"
    public static let inboxFullDismissedDate = "inboxFullDismissedDate"
    public static let inboxTipHiddenPermanently = "inboxTipHiddenPermanently"
    public static let temporarySpeedUp = "temporarySpeedUp"
    public static let temporarySlowDown = "temporarySlowDown"
    public static let cleanupImageCache = "cleanupImageCache"
    public static let autoDeleteWatchedVideos = "autoDeleteWatchedVideos"
    public static let autoDeleteOrphanedVideos = "autoDeleteOrphanedVideos"
    public static let autoDeleteInboxVideosLimit = "autoDeleteInboxVideosLimit"

    /// Persisted history tokens, keyed by model type name
    public static let historyTokens = "historyTokens"
    public static let cleanupHistoryTransactions = "cleanupHistoryTransactions"

    /// Legacy setting, moved to `defaultShortsSetting`
    public static let hideShorts = "hideShortsEverywhere"
    public static let defaultShortsSetting = "defaultShortsSetting"

    public static let navigationManager = "NavigationManager"
    public static let playerManager = "PlayerManager"
    public static let lastAutoRefreshDate = "lastAutoRefreshDate"
    public static let showTabBarLabels = "showTabBarLabels"
    public static let requireClearConfirmation = "requireClearConfirmation"
    public static let showClearQueueButton = "showClearQueueButton"
    public static let useNoCookieUrl = "useNoCookieUrl"
    public static let enableQueueContextMenu = "enableQueueContextMenu"

    /// Quick switch for the two queue slices that aren't tags, and so have nowhere else to keep it
    public static let quickSwitchAllVideos = "quickSwitchAllVideos"
    public static let disableCaptions = "disableCaptions"
    public static let autoCaptionsOnSeekBack = "autoCaptionsOnSeekBack"
    public static let swipeGestureUp = "swipeGestureUp"
    public static let swipeGestureDown = "swipeGestureDown"
    public static let swipeGestureLeft = "swipeGestureLeft"
    public static let swipeGestureRight = "swipeGestureRight"
    public static let doubleTapSeekDuration = "doubleTapSeekDuration"

    public static let automaticBackups = "automaticBackups"
    public static let lastAutoBackupDate = "lastAutoBackupDate"
    public static let includeUnimportantVideosInBackup = "includeUnimportantVideosInBackup"
    public static let includeStatsInBackup = "includeStatsInBackup"
    public static let includeWatchHistoryInBackup = "includeWatchHistoryInBackup"
    public static let autoDeleteBackups = "autoDeleteBackups"
    /// Legacy inverted keys, folded into their `include...InBackup` counterparts
    /// (see `UserDataService.migrateBackupContentSettingsIfNeeded`)
    public static let legacyMinimalBackups = "minimalBackups"
    public static let legacyExcludeStatsInBackup = "excludeStatsInBackup"
    public static let legacyExcludeWatchHistoryInBackup = "exludeWatchHistoryInBackup"
    public static let analytics = "analytics"

    public static let sideloadingSortOrder = "sideloadingSortOrder"
    public static let showTabBarBadge = "showTabBarBadge"
    public static let browserAsTab = "browserAsTab"
    public static let browserDisplayMode = "browserDisplayMode"
    public static let searchAlwaysUseYoutube = "searchAlwaysUseYoutube"
    public static let searchSources = "searchSources"

    public static let selectedDetent = "selectedDetent"
    public static let playerControlHeight = "playerControlHeight"
    public static let sheetHeight = "sheetHeight"
    public static let hideMenuOnPlay = "hideMenuOnPlay"

    public static let videoAddedToInboxNotification = "videoAddedToInboxNotification"
    public static let videoAddedToQueueNotification = "videoAddedToQueueNotification"
    public static let monitorBackgroundFetchesNotification = "monitorBackgroundFetchesNotification"
    public static let badgeCount = "badgeCount"
    public static let showNotificationBadge = "showNotificationBadge"

    public static let lightModeTheme = "lightModeTheme"
    public static let darkModeTheme = "darkModeTheme"
    public static let showTutorial = "showTutorial"
    public static let onboardingCompleted = "onboardingCompleted"
    public static let onboardingStarted = "onboardingStarted"
    public static let lightAppIcon = "lightAppIcon"

    public static let reloadVideoId = "reloadVideoId"
    public static let playbackId = "playbackId"
    public static let fullscreenControlsSetting = "fullscreenControlsSetting"
    public static let preferPlayerType = "preferPlayerType"

    public static let videoListFormat = "videoListFormat"
    public static let inboxAppearance = "inboxAppearance"
    public static let inboxOldestFirst = "inboxOldestFirst"
    public static let hidePlayerPageIndicator = "hidePlayerPageIndicator"

    public static let playerType = "playerType"
    public static let previousPlayerType = "previousPlayerType"
    public static let pipAutoEnable = "pipAutoEnable"

    /// Hours of unplayed queue kept downloaded ahead: 0 off, -1 unlimited
    public static let podcastDownloadLimitHours = "podcastDownloadLimitHours"
    /// Days a downloaded episode is kept after it's been watched; 0 deletes it right away
    public static let podcastDownloadKeepDays = "podcastDownloadKeepDays"
    public static let podcastDownloadOnCellular = "podcastDownloadOnCellular"

    public static let shareExtensionAction = "shareExtensionAction"
    public static let shareExtensionAskedToRemember = "shareExtensionAskedToRemember"
}

public extension Const {
    static var macOS26: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    static var iOS26_1: Bool {
        if #available(iOS 26.1, *) {
            return true
        }
        return false
    }
}
