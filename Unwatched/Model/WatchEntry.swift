//
//  WatchEntry.swift
//  Unwatched
//

import Foundation
import SwiftData

struct SendableWatchEntry: Codable {
    var videoId: Int
    var date: Date?
}
