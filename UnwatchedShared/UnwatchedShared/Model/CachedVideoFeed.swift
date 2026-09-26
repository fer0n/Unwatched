//
//  CachedVideoFeed.swift
//  UnwatchedShared
//

import Foundation
import SwiftData

@Model public final class CachedVideoFeed {
    @Attribute(.unique) public var sourceKey: String
    public var data: Data
    public var updatedDate: Date

    public init(sourceKey: String, data: Data, updatedDate: Date = .now) {
        self.sourceKey = sourceKey
        self.data = data
        self.updatedDate = updatedDate
    }
}
