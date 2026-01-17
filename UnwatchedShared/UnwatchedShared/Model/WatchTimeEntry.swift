//
//  WatchStat.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
public final class WatchTimeEntry: Exportable {
    public typealias ExportType = SendableWatchTimeEntry

    public var date: Date = Date()
    public var channelId: String = ""
    public var watchTime: TimeInterval = 0

    public init(date: Date, channelId: String, watchTime: TimeInterval = 0) {
        self.date = date
        self.channelId = channelId
        self.watchTime = watchTime
    }

    public var toExport: SendableWatchTimeEntry? {
        SendableWatchTimeEntry(
            date: date,
            channelId: channelId,
            channelName: "",
            watchTime: watchTime
        )
    }
}
