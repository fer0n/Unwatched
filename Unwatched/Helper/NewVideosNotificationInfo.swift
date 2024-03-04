//
//  NewVideosNotificationInfo.swift
//  Unwatched
//

import Foundation

struct NewVideosNotificationInfo {
    var inbox = [String: [SendableVideo]]()
    var queue = [String: [SendableVideo]]()

    var videoCount: Int {
        inbox.values.flatMap { $0 }.count + queue.values.flatMap { $0 }.count
    }

    var navigateTo: NavigationTab? {
        if inbox.isEmpty && queue.isEmpty {
            return nil
        }
        if inbox.keys.count > queue.keys.count {
            return .inbox
        }
        return .queue
    }

    mutating func addVideo(_ video: SendableVideo, for subscription: String, in placement: VideoPlacement) {
        if placement == .inbox {
            inbox[subscription, default: []].append(video)
        } else if placement == .queue {
            queue[subscription, default: []].append(video)
        }
    }

    func getNewVideoText(includeInbox: Bool, includeQueue: Bool) -> (title: String, subtitle: String)? {
        if !includeInbox && !includeQueue {
            return nil
        }
        var dict = [String: [SendableVideo]]()

        if includeInbox {
            dict.merge(inbox) { _, new in new }
        }
        if includeQueue {
            dict.merge(queue) { _, new in new }
        }
        return getText(from: dict)
    }

    private func getText(from dict: [String: [SendableVideo]]) -> (title: String, subtitle: String)? {
        let newVideosCount = dict.values.flatMap { $0 }.count
        if newVideosCount == 0 {
            return nil
        }
        if newVideosCount == 1,
           let subscriptionTitle = dict.keys.first,
           let videoTitle = dict.values.flatMap({ $0 }).first?.title {
            return (subscriptionTitle, videoTitle)
        }
        if dict.keys.count == 1, let first = dict.first {
            return (first.key, String(localized: "\(newVideosCount) New Videos"))
        }

        // <SubscriptionTitle> (<videoCount>), <SubscriptionTitle> (<videoCount>)
        let subTitleVideoCounts = dict.map { key, value in
            "\(key) (\(value.count))"
        }
        let title = String(localized: "\(newVideosCount) New Videos")
        let subtitle = subTitleVideoCounts.joined(separator: ", ")
        return (title, subtitle)
    }
}
