//
//  ChapterHandlingContext.swift
//  UnwatchedShared
//

import Foundation
import OSLog
import SwiftData
import UnwatchedShared

struct ChapterHandlingContext {
    var last: SendableChapter
    var chapter: SendableChapter
    var newChapters: [SendableChapter]
    var index: Int
    var tolerance: Double
    var lastEndTime: Double
}
