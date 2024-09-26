//
//  WatchEntry.swift
//  Unwatched
//

import Foundation
import SwiftData

public struct SendableWatchEntry: Codable {
    public var videoId: Int
    public var date: Date?
}
