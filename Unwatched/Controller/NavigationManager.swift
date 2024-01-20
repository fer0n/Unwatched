//
//  NavigationManager.swift
//  Unwatched
//

import Foundation
import SwiftUI
import SwiftData

@Observable class NavigationManager: Codable {
    var video: Video? {
        didSet {
            withAnimation {
                showMenu = false
            }
        }
    }

    var showMenu = true
    var tab = Tab.queue

    var presentedSubscriptionQueue = [Subscription]()
    var presentedSubscriptionInbox = [Subscription]()
    var presentedSubscriptionLibrary = [Subscription]()

    init() { }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: NavManagerCodingKeys.self)

        showMenu = try container.decode(Bool.self, forKey: .showMenu)
        tab = try container.decode(Tab.self, forKey: .tab)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: NavManagerCodingKeys.self)

        try container.encode(showMenu, forKey: .showMenu)
        try container.encode(tab, forKey: .tab)
    }

    func pushSubscription(_ subscription: Subscription) {
        switch tab {
        case .inbox:
            presentedSubscriptionInbox.append(subscription)
        case .queue:
            presentedSubscriptionQueue.append(subscription)
        case .library:
            presentedSubscriptionLibrary.append(subscription)
        }
    }

    static func getDummy() -> NavigationManager {
        let navManager = NavigationManager()
        navManager.video = Video.getDummy()
        return navManager
    }
}

enum NavManagerCodingKeys: CodingKey {
    case showMenu
    case tab
    case video
}

enum Tab: Codable {
    case inbox
    case queue
    case library
}
