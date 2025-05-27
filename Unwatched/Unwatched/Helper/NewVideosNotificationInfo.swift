//
//  NewVideosNotificationInfo.swift
//  Unwatched
//

import Foundation
import SwiftData
import OSLog
import UnwatchedShared

struct NewVideosNotificationInfo {
    var inbox = [String: [SendableVideo]]()
    var queue = [String: [SendableVideo]]()

    var addEntriesOnReceive = false

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

    mutating func addVideo(_ video: SendableVideo, for subscription: String, in placement: VideoPlacementArea) {
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
                                        includeQueue: Bool) async -> ([NotificationInfo], Int) {
        if !includeInbox && !includeQueue {
            return ([], 0)
        }

        let countInbox = includeInbox ? inbox.values.flatMap { $0 }.count : 0
        let countQueue = includeQueue ? queue.values.flatMap { $0 }.count : 0
        let count = countInbox + countQueue

        if count <= Const.simultaneousNotificationsLimit {
            let info = sendOneNotificationPerVideo(includeInbox, includeQueue)
            let infoWithImages = await getImageData(info)
            return (infoWithImages, count)
        } else {
            return (sendOneQueueOneInboxNotification(includeInbox, includeQueue), count)
        }
    }

    func getImageData(_ infos: [NotificationInfo]) async -> [NotificationInfo] {
        var infoWithImageData = infos

        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, info) in infos.enumerated() {
                guard let video = info.video,
                      video.thumbnailData == nil,
                      let imageUrl = video.thumbnailUrl else {
                    Log.info("No video/imageUrl when trying to load image data")
                    continue
                }

                group.addTask {
                    do {
                        let data = try await ImageService.loadImageData(url: imageUrl)
                        return (index, data)
                    } catch {
                        Log.info("Failed to load image data for \(info.title): \(error)")
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

    private func sendOneQueueOneInboxNotification(_ includeInbox: Bool, _ includeQueue: Bool) -> [NotificationInfo] {
        var notifications = [NotificationInfo?]()
        if includeInbox {
            notifications.append(getText(from: inbox, placement: .inbox))
        }
        if includeQueue {
            notifications.append(getText(from: queue, placement: .queue))
        }
        return notifications.compactMap { $0 }
    }

    private func sendOneNotificationPerVideo(_ includeInbox: Bool, _ includeQueue: Bool) -> [NotificationInfo] {
        var result = [NotificationInfo]()
        if includeInbox {
            for flat in flattenDicts(inbox) {
                if let info = getText(from: flat, placement: .inbox) {
                    result.append(info)
                }
            }
        }
        if includeQueue {
            for flat in flattenDicts(queue) {
                if let info = getText(from: flat, placement: .queue) {
                    result.append(info)
                }
            }
        }
        return result
    }

    private func getText(from dict: [String: [SendableVideo]], placement: VideoPlacementArea) -> NotificationInfo? {
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
