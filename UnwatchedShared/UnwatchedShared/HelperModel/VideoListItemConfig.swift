//
//  VideoListItemConfig.swift
//  Unwatched
//

import SwiftUI

public struct VideoListItemConfig {
    public let hasInboxEntry: Bool?
    public let hasQueueEntry: Bool?
    public let videoDuration: Double?
    public let watched: Bool?
    public let deferred: Bool?
    public let isNew: Bool?
    public let showPlayingStatus: Bool
    public let clearRole: ButtonRole?
    public let queueRole: ButtonRole?
    public let onChange: (() -> Void)?
    public let clearAboveBelowList: ClearList?
    public let showQueueButton: Bool
    public let showContextMenu: Bool
    public let showVideoListOrder: Bool
    public let showDelete: Bool
    public let async: Bool

    public init(
        hasInboxEntry: Bool? = nil,
        hasQueueEntry: Bool? = nil,
        videoDuration: Double? = nil,
        watched: Bool? = nil,
        deferred: Bool? = nil,
        isNew: Bool = false,
        showPlayingStatus: Bool = true,
        clearRole: ButtonRole? = nil,
        queueRole: ButtonRole? = nil,
        onChange: (() -> Void)? = nil,
        clearAboveBelowList: ClearList? = nil,
        showQueueButton: Bool = false,
        showContextMenu: Bool = true,
        showVideoListOrder: Bool = false,
        showDelete: Bool = true,
        async: Bool = false
    ) {
        self.hasInboxEntry = hasInboxEntry
        self.hasQueueEntry = hasQueueEntry
        self.videoDuration = videoDuration
        self.watched = watched
        self.deferred = deferred
        self.isNew = isNew
        self.showPlayingStatus = showPlayingStatus
        self.clearRole = clearRole
        self.queueRole = queueRole
        self.onChange = onChange
        self.clearAboveBelowList = clearAboveBelowList
        self.showQueueButton = showQueueButton
        #if os(iOS)
        self.showContextMenu = showContextMenu
        #else
        self.showContextMenu = true
        #endif
        self.showVideoListOrder = showVideoListOrder
        self.showDelete = showDelete
        self.async = async
    }
}
