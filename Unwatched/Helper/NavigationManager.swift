//
//  NavigationManager.swift
//  Unwatched
//

import Foundation
import SwiftUI

@Observable class NavigationManager {
    var video: Video? {
        didSet {
            if let value = oldValue {
                previousVideo = value
            }
        }
    }
    var previousVideo: Video?

    var tab = Tab.queue
    var previousTab = Tab.queue

    var presentedSubscriptionQueue = [Subscription]()
    var presentedSubscriptionInbox = [Subscription]()
    var presentedSubscriptionLibrary = [Subscription]()

    func pushSubscription(_ subscription: Subscription) {
        switch tab {
        case .videoPlayer:
            return
        case .inbox:
            presentedSubscriptionInbox.append(subscription)
        case .queue:
            presentedSubscriptionQueue.append(subscription)
        case .library:
            presentedSubscriptionLibrary.append(subscription)
        }
    }
}
