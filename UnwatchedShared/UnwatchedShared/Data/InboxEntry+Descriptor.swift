//
//  InboxEntry+Descriptor.swift
//  UnwatchedShared
//

import SwiftData

public extension InboxEntry {
    static func descriptor(oldestFirst: Bool, limit: Int? = nil) -> FetchDescriptor<InboxEntry> {
        var descriptor = FetchDescriptor<InboxEntry>(
            sortBy: [SortDescriptor(\InboxEntry.date, order: oldestFirst ? .forward : .reverse)]
        )
        descriptor.fetchLimit = min(limit ?? Const.inboxFetchLimit, Const.inboxFetchLimit)
        return descriptor
    }
}
