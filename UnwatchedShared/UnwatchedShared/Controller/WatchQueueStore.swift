//
//  WatchQueueStore.swift
//  UnwatchedShared
//

#if os(watchOS)
import Foundation
import SwiftData

/// The queue the phone hands over, as rows in `DataProvider.quickContainer`.
public enum WatchQueueStore {
    @MainActor
    public static func replace(with snapshot: WatchQueueSnapshot) throws {
        let context = DataProvider.quickContainer.mainContext
        try deleteAll(in: context)

        var subscriptions = [String: Subscription]()
        var videos = [String: Video]()
        for item in snapshot.items.sorted(by: { $0.order < $1.order }) {
            let video = Video(
                title: item.title,
                url: nil,
                youtubeId: item.youtubeId,
                thumbnailUrl: item.thumbnailUrl,
                duration: item.duration,
                elapsedSeconds: item.elapsedSeconds,
                mediaUrl: item.mediaUrl,
                isAudioOnly: item.isAudioOnly
            )
            context.insert(video)
            videos[item.youtubeId] = video

            if let channelTitle = item.channelTitle {
                video.subscription = subscriptions[channelTitle] ?? {
                    let subscription = Subscription(
                        link: nil,
                        title: channelTitle,
                        customSpeedSetting: item.customSpeedSetting,
                        thumbnailUrl: item.channelThumbnailUrl
                    )
                    context.insert(subscription)
                    subscriptions[channelTitle] = subscription
                    return subscription
                }()
            }

            context.insert(QueueEntry(video: video, order: item.order))
        }

        for item in snapshot.tags {
            let tag = Tag(
                name: item.name,
                order: item.order,
                symbol: item.symbol,
                quickSwitch: item.quickSwitch,
                mode: TagMode(rawValue: item.mode) ?? .include,
                continuousPlay: item.continuousPlay,
                seekSeconds: item.seekSeconds,
                playbackSpeed: item.playbackSpeed
            )
            context.insert(tag)
            tag.subscriptions = item.channelTitles.compactMap { subscriptions[$0] }
            tag.videos = item.youtubeIds.compactMap { videos[$0] }
        }

        try context.save()
    }

    @MainActor
    public static func clear() throws {
        let context = DataProvider.quickContainer.mainContext
        try deleteAll(in: context)
        try context.save()
        UserDefaults.standard.removeObject(forKey: Const.watchQueueUpdatedDate)
    }

    @MainActor
    private static func deleteAll(in context: ModelContext) throws {
        try context.delete(model: QueueEntry.self)
        try context.delete(model: Video.self)
        try context.delete(model: Subscription.self)
        try context.delete(model: Tag.self)
    }
}
#endif
