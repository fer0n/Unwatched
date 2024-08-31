//
//  VideoListItemConfig.swift
//  Unwatched
//

import SwiftUI

struct VideoListItemConfig {
    var showVideoStatus: Bool = false
    var hasInboxEntry: Bool?
    var hasQueueEntry: Bool?
    var videoDuration: Double?
    var watched: Bool?
    var clearRole: ButtonRole?
    var queueRole: ButtonRole?
    var onChange: (() -> Void)?
    var clearAboveBelowList: ClearList?
    var videoSwipeActions: [VideoActions] = [.queueTop, .queueBottom, .clear, .more, .details]
    var showQueueButton: Bool = false
    var showContextMenu: Bool = true
}
