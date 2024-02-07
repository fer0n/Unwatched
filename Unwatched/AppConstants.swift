//
//  App Constants.swift
//  Unwatched
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI

struct Const {

    static let sensoryFeedback = SensoryFeedback.impact(intensity: 0.6)

    static let playerAboveSheetHeight: CGFloat = 60
    static let backupType = UTType("com.pentlandFirth.unwatchedbackup")

    // videos of new subscriptions being triaged
    static let triageNewSubs = 5
    static let minInboxEntriesToShowClear = 4
    static let autoRefreshIntervalSeconds: Double = 10 * 60

    // MARK: - SF Symbols
    static let refreshSF = "arrow.triangle.2.circlepath"
    static let videoPlayerTabSF = "chevron.up.circle"
    static let queueTagSF = "rectangle.stack"
    static let inboxTabEmptySF = "tray"
    static let inboxTabFullSF = "tray.full"
    static let libraryTabSF = "books.vertical.fill"

    static let settingsViewSF = "gearshape.fill"
    static let allVideosViewSF = "play.rectangle.on.rectangle"
    static let watchHistoryViewSF = "checkmark.circle"

    static let sideloadSF = "arrow.right.circle"

    static let filterSF = "line.3.horizontal.decrease.circle.fill"
    static let addSF = "plus"

    static let watchedSF = "checkmark.circle.fill"
    static let clearSF = "xmark.circle.fill"

    static let alreadyInLibrarySF = "books.vertical.circle.fill"

    static let rateAppSF = "star.fill"
    static let contactMailSF = "envelope.fill"
    static let listItemChevronSF = "chevron.right"

    static let circleBackgroundSF = "circle.fill"
    static let checkmarkSF = "checkmark"

    // MARK: - AppStorage
    static let subscriptionSortOrder = "subscriptionSortOrder"
    static let playVideoFullscreen = "playVideoFullscreen"
    static let autoplayVideos = "autoplayVideos"
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

    static let automaticBackups = "automaticBackups"
    static let lastAutoBackupDate = "lastAutoBackupDate"

    static let shortcutHasBeenUsed = "shortcutHasBeenUsed"
}
