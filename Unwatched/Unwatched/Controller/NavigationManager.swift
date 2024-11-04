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
    var showMenu = false
    var openBrowserUrl: BrowserUrl?
    var openTabBrowserUrl: BrowserUrl?

    var videoDetail: Video?
    var videoDetailPage: ChapterDescriptionPage = .description

    var tab = NavigationTab.queue
    var showDescriptionDetail = false
    var selectedDetailPage: ChapterDescriptionPage = .description
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

    func openUrlInApp(_ url: BrowserUrl) {
        if UserDefaults.standard.bool(forKey: Const.browserAsTab) {
            openTabBrowserUrl = url
            tab = .browser
            showMenu = true
        } else {
            openBrowserUrl = url
        }
    }

    func handlePlay() {
        let hideMenuOnPlay = UserDefaults.standard.value(forKey: Const.hideMenuOnPlay) as? Bool ?? true
        let rotateOnPlay = UserDefaults.standard.bool(forKey: Const.rotateOnPlay)
        let returnToQueue = UserDefaults.standard.bool(forKey: Const.returnToQueue)

        if hideMenuOnPlay || rotateOnPlay {
            withAnimation {
                showMenu = false
            }
        }

        if returnToQueue {
            navigateToQueue()
        }
    }

    static func getDummy() -> NavigationManager {
        let navManager = NavigationManager()
        navManager.showMenu = true
        return navManager
    }
}

enum NavManagerCodingKeys: CodingKey {
    case showMenu,
         tab,
         askForReviewPoints,
         presentedLibrary,
         presentedSubscriptionInbox,
         presentedSubscriptionQueue
}

enum NavigationTab: String, Codable {
    case inbox
    case queue
    case library
    case browser
}
