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

    func getNewVideoText(includeInbox: Bool, includeQueue: Bool) -> [NotificationInfo] {
        if !includeInbox && !includeQueue {
            return []
        }
        let result: [NotificationInfo] = [
            getText(from: inbox, placement: .inbox),
            getText(from: queue, placement: .queue)
        ].compactMap { $0 }

        return result
    }

    private func getText(from dict: [String: [SendableVideo]], placement: VideoPlacement) -> NotificationInfo? {
        let newVideosCount = dict.values.flatMap { $0 }.count
        let prefix = placement == .inbox ? "" : "→ "
        if newVideosCount == 0 {
            return nil
        }
        if newVideosCount == 1,
           let subscriptionTitle = dict.keys.first,
           let video = dict.values.flatMap({ $0 }).first {
            return NotificationInfo(subscriptionTitle, "\(prefix)\(video.title)", video: video, placement: placement)
        }
        if dict.keys.count == 1, let first = dict.first {
            return NotificationInfo(first.key,
                                    String(localized: "\(prefix)\(newVideosCount) New Videos"))
        }

        // <SubscriptionTitle> (<videoCount>), <SubscriptionTitle> (<videoCount>)
        let subTitleVideoCounts = dict.map { key, value in
            "\(key) (\(value.count))"
        }
        let title = String(localized: "\(newVideosCount) New Videos")
        let subtitle = subTitleVideoCounts.joined(separator: ", ")
        return NotificationInfo(title, "\(prefix)\(subtitle)")
    }
}

struct NotificationInfo {
    let title: String
    let subtitle: String

    let categoryIdentifier: String?
    let video: SendableVideo?

    init(_ title: String, _ subtitle: String, video: SendableVideo? = nil, placement: VideoPlacement? = nil) {
        self.title = title
        self.subtitle = subtitle

        self.video = video

        var categoryIdentifier: String?
        if video != nil {
            // find out if the video is in the inbox or queue
            categoryIdentifier = placement == .queue
                ? Const.queueVideoAddedCategory
                : placement == .inbox
                ? Const.inboxVideoAddedCategory
                : nil
        }
        self.categoryIdentifier = categoryIdentifier
    }
}
