//
//  VideoListItemConfig.swift
//  Unwatched
//

import SwiftUI

public struct VideoListItemConfig: Equatable, Sendable {
    public static func == (lhs: VideoListItemConfig, rhs: VideoListItemConfig) -> Bool {
        lhs.hasInboxEntry == rhs.hasInboxEntry &&
        lhs.hasQueueEntry == rhs.hasQueueEntry &&
        lhs.videoDuration == rhs.videoDuration &&
        lhs.watched == rhs.watched &&
        lhs.deferred == rhs.deferred &&
        lhs.isNew == rhs.isNew &&
        lhs.showQueueButton == rhs.showQueueButton &&
        lhs.showContextMenu == rhs.showContextMenu
    }
    
    public let hasInboxEntry: Bool?
    public let hasQueueEntry: Bool?
    public let videoDuration: Double?
    public let watched: Bool?
    public let deferred: Bool?
    public let isNew: Bool?
    public let showAllStatus: Bool
    public let clearRole: ButtonRole?
    public let queueRole: ButtonRole?
    public let clearAboveBelowList: ClearList?
    public let showQueueButton: Bool
    public let showContextMenu: Bool
    public let showDelete: Bool
    public let async: Bool

    public init(
        hasInboxEntry: Bool? = nil,
        hasQueueEntry: Bool? = nil,
        videoDuration: Double? = nil,
        watched: Bool? = nil,
        deferred: Bool? = nil,
        isNew: Bool = false,
        showAllStatus: Bool = true,
        clearRole: ButtonRole? = nil,
        queueRole: ButtonRole? = nil,
        clearAboveBelowList: ClearList? = nil,
        showQueueButton: Bool = false,
        showContextMenu: Bool = true,
        showDelete: Bool = true,
        async: Bool = false
    ) {
        self.hasInboxEntry = hasInboxEntry
        self.hasQueueEntry = hasQueueEntry
        self.videoDuration = videoDuration
        self.watched = watched
        self.deferred = deferred
        self.isNew = isNew
        self.showAllStatus = showAllStatus
        self.clearRole = clearRole
        self.queueRole = queueRole
        self.clearAboveBelowList = clearAboveBelowList
        self.showQueueButton = showQueueButton
        #if os(iOS)
        self.showContextMenu = showContextMenu
        #else
        self.showContextMenu = true
        #endif
        self.showDelete = showDelete
        self.async = async
    }
}

public enum ChangeReason: Sendable {
    case clear,
         queue,
         clearAbove,
         clearBelow
}
