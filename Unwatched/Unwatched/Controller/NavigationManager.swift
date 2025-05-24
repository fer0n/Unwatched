//
//  NavigationManager.swift
//  Unwatched
//

import Foundation
import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

@Observable class NavigationManager: Codable {
    @MainActor
    static let shared: NavigationManager = {
        NavigationManager.load()
    }()

    var showMenu = false
    var openBrowserUrl: BrowserUrl?
    var openTabBrowserUrl: BrowserUrl?
    var openWindow: OpenWindowAction?
    var columnVisibility: NavigationSplitViewVisibility = .automatic
    var showDeferDateSelector = false

    var isMacosFullscreen = false

    var videoDetail: Video?
    var playerTab: ControlNavigationTab = .controls
    @ObservationIgnored var scrollToCurrentChapter = false

    var tab = NavigationTab.queue
    var searchFocused = false

    var askForReviewPoints = 0

    var presentedSubscriptionQueue = [SendableSubscription]()
    var presentedSubscriptionInbox = [SendableSubscription]()
    var presentedLibrary = NavigationPath()

    @ObservationIgnored var topListItemId: String?
    @ObservationIgnored private var lastTabTwiceDate: Date?
    var lastLibrarySubscriptionId: PersistentIdentifier?
    var lastInboxSubscriptionId: PersistentIdentifier?
    var lastQueueSubscriptionId: PersistentIdentifier?

    init() { }

    static func load() -> NavigationManager {
        if let savedNavManager = UserDefaults.standard.data(forKey: Const.navigationManager),
           let loadedNavManager = try? JSONDecoder().decode(NavigationManager.self, from: savedNavManager) {
            return loadedNavManager
        } else {
            Logger.log.info("navManager not found")
            return NavigationManager()
        }
    }

    func save() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            UserDefaults.standard.set(encoded, forKey: Const.navigationManager)
        }
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: NavManagerCodingKeys.self)

        showMenu = try container.decode(Bool.self, forKey: .showMenu)
        tab = try container.decode(NavigationTab.self, forKey: .tab)
        askForReviewPoints = try container.decode(Int.self, forKey: .askForReviewPoints)

        let decoded = try container.decode(NavigationPath.CodableRepresentation.self, forKey: .presentedLibrary)
        presentedLibrary = NavigationPath(decoded)

        presentedSubscriptionInbox = try container.decode(
            [SendableSubscription].self,
            forKey: .presentedSubscriptionInbox
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: NavManagerCodingKeys.self)

        try container.encode(showMenu, forKey: .showMenu)
        try container.encode(tab, forKey: .tab)
        try container.encode(askForReviewPoints, forKey: .askForReviewPoints)

        if let representation = presentedLibrary.codable {
            try container.encode(representation, forKey: .presentedLibrary)
        }
        try container.encode(presentedSubscriptionInbox, forKey: .presentedSubscriptionInbox)
    }

    func pushSubscription(
        subscription: Subscription? = nil,
        sendableSubscription: SendableSubscription? = nil
    ) {
        guard let sendableSub = sendableSubscription ?? subscription?.toExport else {
            Logger.log.error("pushSubscription: no subscription given")
            return
        }
        switch tab {
        case .inbox:
            if presentedSubscriptionInbox.last != sendableSub {
                presentedSubscriptionInbox.append(sendableSub)
                lastInboxSubscriptionId = sendableSub.persistentId
            }
        case .queue:
            if presentedSubscriptionQueue.last != sendableSub {
                presentedSubscriptionQueue.append(sendableSub)
                lastQueueSubscriptionId = sendableSub.persistentId
            }
        case .browser:
            tab = .library
            pushToLibrary(sendableSub)
        case .library:
            pushToLibrary(sendableSub)
        }
    }

    func pushToLibrary(_ sendableSub: SendableSubscription) {
        if lastLibrarySubscriptionId != sendableSub.persistentId {
            presentedLibrary.append(sendableSub)
            lastLibrarySubscriptionId = sendableSub.persistentId
        }
    }

    func navigateTo(_ tab: NavigationTab) {
        self.tab = tab
        if !showMenu {
            showMenu = true
        }
        Task { @MainActor in
            if SheetPositionReader.shared.isMinimumSheet {
                SheetPositionReader.shared.setDetentVideoPlayer()
            }
        }
    }

    func navigateToQueue() {
        self.tab = .queue
        presentedSubscriptionQueue.removeAll()
    }

    func setScrollId(_ value: String?, _ differentiator: String = "") {
        topListItemId = NavigationManager.getScrollId(value, differentiator)
    }

    static func getScrollId(_ value: String?, _ differentiator: String = "") -> String {
        "scrollId-\(differentiator)-\(value ?? "")"
    }

    func handleTappedTwice() -> Bool {
        var isOnTopView = false
        switch tab {
        case .inbox:
            isOnTopView = presentedSubscriptionInbox.isEmpty
        case .queue:
            isOnTopView = presentedSubscriptionQueue.isEmpty
        case .library:
            isOnTopView = presentedLibrary.isEmpty
        case .browser:
            openTabBrowserUrl = .youtubeStartPage
        }

        if !isOnTopView, #unavailable(iOS 18) {
            // happens automatically on iOS 18
            clearNavigationStack(tab)
        }
        return isOnTopView
    }

    func clearNavigationStack(_ tab: NavigationTab) {
        switch tab {
        case .inbox:
            presentedSubscriptionInbox.removeAll()
            lastInboxSubscriptionId = nil
        case .queue:
            presentedSubscriptionQueue.removeAll()
            lastQueueSubscriptionId = nil
        case .library:
            lastLibrarySubscriptionId = nil
            presentedLibrary = NavigationPath()
        case .browser:
            break
        }
    }

    @MainActor
    func openUrlInApp(_ url: BrowserUrl) {
        UserDefaults.standard.set(false, forKey: Const.hideControlsFullscreen)
        if UserDefaults.standard.bool(forKey: Const.browserAsTab) {
            SheetPositionReader.shared.setDetentMiniPlayer()
            openTabBrowserUrl = url
            tab = .browser
            showMenu = true
        } else {
            openBrowserUrl = url
            #if os(macOS)
            openWindow?(id: Const.windowBrowser)
            #endif
        }
    }

    @MainActor
    func handlePlay() {
        let rotateOnPlay = UserDefaults.standard.bool(forKey: Const.rotateOnPlay)
        let returnToQueue = UserDefaults.standard.bool(forKey: Const.returnToQueue)

        if searchFocused {
            searchFocused = false
        }

        if (Const.hideMenuOnPlay.bool ?? true) || rotateOnPlay {
            #if os(macOS)
            toggleSidebar(show: false)
            #else
            withAnimation {
                SheetPositionReader.shared.setDetentMinimumSheet()
            }
            #endif
        }

        if SheetPositionReader.shared.landscapeFullscreen {
            showMenu = false
        }

        if returnToQueue {
            navigateToQueue()
        }
    }

    func handleRequestReview(_ requestReview: @escaping () -> Void) {
        askForReviewPoints += 1
        if askForReviewPoints >= Const.askForReviewPointThreshold {
            askForReviewPoints = -70
            requestReview()
        }
    }

    func handleVideoDetail(scrollToCurrentChapter: Bool = false) {
        self.scrollToCurrentChapter = scrollToCurrentChapter
        withAnimation {
            playerTab = .chapterDescription
        }
    }

    func toggleSidebar(show: Bool? = nil) {
        let shouldShow = show ?? isSidebarHidden
        columnVisibility = shouldShow ? .all : .detailOnly
    }

    var isSidebarHidden: Bool {
        columnVisibility == .detailOnly
    }

    var hasSheetOpen: Bool {
        videoDetail != nil || openBrowserUrl != nil
    }

    static func getDummy(_ showMenu: Bool = true) -> NavigationManager {
        let navManager = NavigationManager()
        navManager.showMenu = showMenu
        return navManager
    }
}

enum NavManagerCodingKeys: CodingKey {
    case showMenu,
         tab,
         askForReviewPoints,
         presentedLibrary,
         presentedSubscriptionInbox,
         presentedSubscriptionQueue,
         columnVisibility
}

enum NavigationTab: String, Codable, CustomStringConvertible {
    case inbox
    case queue
    case library
    case browser

    var description: String {
        switch self {
        case .inbox:
            return String(localized: "inbox")
        case .queue:
            return String(localized: "queue")
        case .library:
            return String(localized: "library")
        case .browser:
            return String(localized: "browserShort")
        }
    }

    var stringKey: LocalizedStringKey {
        switch self {
        case .inbox:
            return "inbox"
        case .queue:
            return "queue"
        case .library:
            return "library"
        case .browser:
            return "browserShort"
        }
    }
}

enum ControlNavigationTab: Int {
    case controls
    case chapterDescription
}
