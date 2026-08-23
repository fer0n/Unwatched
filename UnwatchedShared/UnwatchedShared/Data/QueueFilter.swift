//
//  QueueFilter.swift
//  UnwatchedShared
//

import Foundation
import SwiftData
import SwiftUI

/// Which slice of the queue a read or a write applies to. Every queue read goes through here.
public struct QueueFilter: Hashable, Sendable {
    /// `nil` is the whole queue.
    public let subscriptionIds: [PersistentIdentifier]?

    public let videoIds: [String]

    public let isExcluding: Bool

    public static let all = QueueFilter(subscriptionIds: nil)

    public init(
        subscriptionIds: [PersistentIdentifier]?,
        videoIds: [String] = [],
        isExcluding: Bool = false
    ) {
        self.subscriptionIds = subscriptionIds
        self.videoIds = videoIds
        self.isExcluding = isExcluding
    }

    /// - Parameter tags: every tag, for what an `untagged` tag measures against.
    public init(tag: Tag?, in tags: [Tag]) {
        guard let tag else {
            self = .all
            return
        }
        switch tag.mode {
        case .include:
            self.init(tag.subscriptions, tag.videos)
        case .exclude:
            self.init(tag.subscriptions, tag.videos, isExcluding: true)
        case .untagged:
            self.init(Tag.coveredSubscriptions(tags), Tag.coveredVideos(tags), isExcluding: true)
        }
    }

    private init(_ subscriptions: [Subscription]?, _ videos: [Video]?, isExcluding: Bool = false) {
        self.init(
            subscriptionIds: (subscriptions ?? []).map(\.persistentModelID),
            videoIds: (videos ?? []).map(\.youtubeId),
            isExcluding: isExcluding
        )
    }

    public init(_ selection: QueueTagSelection, _ tags: [Tag]) {
        switch selection {
        case .all:
            self = .all
        case .tag:
            self.init(tag: selection.tag(in: tags), in: tags)
        }
    }

    public var isActive: Bool {
        subscriptionIds != nil
    }

    public func descriptor(limit: Int? = nil) -> FetchDescriptor<QueueEntry> {
        var descriptor = FetchDescriptor<QueueEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\QueueEntry.order)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    /// `flatMap`, not optional chaining: only that shape translates to a plain `IN`.
    private var predicate: Predicate<QueueEntry>? {
        guard let subscriptionIds else { return nil }
        let isExcluding = isExcluding
        guard !videoIds.isEmpty else {
            return #Predicate<QueueEntry> { entry in
                (entry.video.flatMap { video in
                    video.subscription.flatMap { subscription in
                        subscriptionIds.contains(subscription.persistentModelID)
                    }
                } ?? false) != isExcluding
            }
        }
        let videoIds = videoIds
        return #Predicate<QueueEntry> { entry in
            (entry.video.flatMap { video in
                (video.subscription.flatMap { subscription in
                    subscriptionIds.contains(subscription.persistentModelID)
                } ?? false) || videoIds.contains(video.youtubeId)
            } ?? false) != isExcluding
        }
    }

    public func entries(_ context: ModelContext, limit: Int? = nil) -> [QueueEntry] {
        (try? context.fetch(descriptor(limit: limit))) ?? []
    }

    public func videos(_ context: ModelContext, limit: Int? = nil) -> [Video] {
        entries(context, limit: limit).compactMap(\.video)
    }

    /// The single definition of "next up", so the prefetch and the switch can't disagree.
    ///
    /// - Parameter entries: already filtered, and no shorter than two rows unless the slice is.
    public func nextVideo(skipping currentYoutubeId: String?, in entries: [QueueEntry]) -> Video? {
        let first = entries.first?.video
        let second = entries.count > 1 ? entries[1].video : nil
        if first?.youtubeId == currentYoutubeId && second?.youtubeId == currentYoutubeId {
            return nil
        }
        return first?.youtubeId != currentYoutubeId ? first : second
    }

    public func nextVideo(skipping currentYoutubeId: String?, _ context: ModelContext) -> Video? {
        nextVideo(skipping: currentYoutubeId, in: entries(context, limit: 2))
    }

    public func isEmpty(_ context: ModelContext) -> Bool {
        entries(context, limit: 1).isEmpty
    }

    /// Ask *before* changing the queue: once the entry is gone there is nothing to compare.
    public func isTopOfQueue(order: Int?, _ context: ModelContext) -> Bool {
        guard let order, let top = entries(context, limit: 1).first else { return false }
        return top.order == order
    }
}

private struct QueueFilterKey: EnvironmentKey {
    static let defaultValue: QueueFilter = .all
}

public extension EnvironmentValues {
    /// Set by the queue screen so its actions operate on the rows the user can see.
    var queueFilter: QueueFilter {
        get { self[QueueFilterKey.self] }
        set { self[QueueFilterKey.self] = newValue }
    }
}
