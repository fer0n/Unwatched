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

    var presentedSubscriptionQueue = [Subscription]()
    var presentedSubscriptionInbox = [Subscription]()
    var presentedLibrary = NavigationPath() {
        didSet {
            if oldValue.count > presentedLibrary.count {
                lastLibrarySubscriptionId = nil
            }
        }
    }

    @ObservationIgnored var topListItemId: String?
    @ObservationIgnored private var lastTabTwiceDate: Date?
    var lastLibrarySubscriptionId: PersistentIdentifier?

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
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: NavManagerCodingKeys.self)

        try container.encode(showMenu, forKey: .showMenu)
        try container.encode(tab, forKey: .tab)
        try container.encode(askForReviewPoints, forKey: .askForReviewPoints)
    }

    func pushSubscription(_ subscription: Subscription) {
        switch tab {
        case .inbox:
            if presentedSubscriptionInbox.last != subscription {
                presentedSubscriptionInbox.append(subscription)
            }
        case .queue:
            if presentedSubscriptionQueue.last != subscription {
                presentedSubscriptionQueue.append(subscription)
            }
        case .browser:
            tab = .library
            pushToLibrary(subscription)
        case .library:
            pushToLibrary(subscription)
        }
    }

    func pushToLibrary(_ subscription: Subscription) {
        if lastLibrarySubscriptionId != subscription.persistentModelID {
            presentedLibrary.append(subscription)
            lastLibrarySubscriptionId = subscription.persistentModelID
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

        if !isOnTopView {
            popCurrentNaviagtionStack()
        }
        return isOnTopView
    }

    func popCurrentNaviagtionStack() {
        switch tab {
        case .inbox:
            _ = presentedSubscriptionInbox.popLast()
        case .queue:
            _ = presentedSubscriptionQueue.popLast()
        case .library:
            if !presentedLibrary.isEmpty {
                presentedLibrary.removeLast()
                lastLibrarySubscriptionId = nil
            }
        case .browser:
            break
        }
    }

    func clearNavigationStack(_ tab: NavigationTab) {
        switch tab {
        case .inbox:
            presentedSubscriptionInbox.removeAll()
        case .queue:
            presentedSubscriptionQueue.removeAll()
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

    static func getDummy() -> NavigationManager {
        let navManager = NavigationManager()
        navManager.showMenu = true
        return navManager
    }
}

enum NavManagerCodingKeys: CodingKey {
    case showMenu, tab, askForReviewPoints

}

enum NavigationTab: String, Codable {
    case inbox
    case queue
    case library
    case browser
}
