//
//  NewVideosNotificationInfo.swift
//  Unwatched
//

import Foundation
import UIKit
import SwiftData
import OSLog
import UnwatchedShared

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

    func flattenDicts(_ dict: [String: [SendableVideo]]) -> [[String: [SendableVideo]]] {
        // only one key & one value per dict
        var result = [[String: [SendableVideo]]]()
        for (key, value) in dict {
            for val in value {
                result.append([key: [val]])
            }
        }
        return result
    }

    func getNewVideoNotificationContent(includeInbox: Bool,
                                        includeQueue: Bool) async -> [NotificationInfo] {
        if !includeInbox && !includeQueue {
            return []
        }
        let countInbox = inbox.values.flatMap { $0 }.count
        let countQueue = queue.values.flatMap { $0 }.count
        let count = countInbox + countQueue

        if count <= Const.simultaneousNotificationsLimit {
            let info = sendOneNotificationPerVideo()
            let infoWithImages = await getImageData(info)
            return infoWithImages

        } else {
            return sendOneQueueOneInboxNotification()
        }
    }

    private func getImageData(_ infos: [NotificationInfo]) async -> [NotificationInfo] {
        var infoWithImageData = infos

        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, info) in infos.enumerated() {
                guard let video = info.video,
                      video.thumbnailData == nil,
                      let imageUrl = video.thumbnailUrl else {
                    Logger.log.info("No video/imageUrl when trying to load image data")
                    continue
                }

                group.addTask {
                    do {
                        let data = try await ImageService.loadImageData(url: imageUrl)
                        return (index, data)
                    } catch {
                        Logger.log.info("Failed to load image data for \(info.title): \(error)")
                        return (index, nil)
                    }
                }
            }

            for await (index, data) in group {
                if let data = data, let video = infoWithImageData[index].video {
                    var videoWithImageData = video
                    videoWithImageData.thumbnailData = data
                    infoWithImageData[index].video = videoWithImageData
                }
            }
        }

        ImageService.storeImages(for: infoWithImageData)
        return infoWithImageData
    }

    private func sendOneQueueOneInboxNotification() -> [NotificationInfo] {
        [
            getText(from: inbox, placement: .inbox),
            getText(from: queue, placement: .queue)
        ].compactMap { $0 }
    }

    private func sendOneNotificationPerVideo() -> [NotificationInfo] {
        var result = [NotificationInfo]()
        for flat in flattenDicts(inbox) {
            if let info = getText(from: flat, placement: .inbox) {
                result.append(info)
            }
        }
        for flat in flattenDicts(queue) {
            if let info = getText(from: flat, placement: .queue) {
                result.append(info)
            }
        }
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
