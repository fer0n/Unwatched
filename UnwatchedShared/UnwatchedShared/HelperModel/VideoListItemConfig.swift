//
//  VideoListItemConfig.swift
//  Unwatched
//

import SwiftUI

public struct VideoListItemConfig {
    public var showVideoStatus: Bool
    public var hasInboxEntry: Bool?
    public var hasQueueEntry: Bool?
    public var videoDuration: Double?
    public var watched: Bool?
    public var clearRole: ButtonRole?
    public var queueRole: ButtonRole?
    public var onChange: (() -> Void)?
    public var clearAboveBelowList: ClearList?
    public var videoSwipeActions: [VideoActions]
    public var showQueueButton: Bool
    public var showContextMenu: Bool
    public var showVideoListOrder: Bool
    public var async: Bool

    public init(
        showVideoStatus: Bool = false,
        hasInboxEntry: Bool? = nil,
        hasQueueEntry: Bool? = nil,
        videoDuration: Double? = nil,
        watched: Bool? = nil,
        clearRole: ButtonRole? = nil,
        queueRole: ButtonRole? = nil,
        onChange: (() -> Void)? = nil,
        clearAboveBelowList: ClearList? = nil,
        videoSwipeActions: [VideoActions] = [.queueTop, .queueBottom, .clear, .more, .details],
        showQueueButton: Bool = false,
        showContextMenu: Bool = true,
        showVideoListOrder: Bool = false,
        async: Bool = false
    ) {
        self.showVideoStatus = showVideoStatus
        self.hasInboxEntry = hasInboxEntry
        self.hasQueueEntry = hasQueueEntry
        self.videoDuration = videoDuration
        self.watched = watched
        self.clearRole = clearRole
        self.queueRole = queueRole
        self.onChange = onChange
        self.clearAboveBelowList = clearAboveBelowList
        self.videoSwipeActions = videoSwipeActions
        self.showQueueButton = showQueueButton
        self.showContextMenu = showContextMenu
        self.showVideoListOrder = showVideoListOrder
        self.async = async
    }
}
