//
//  ChapterService+Reconcile.swift
//  Unwatched
//

import Foundation
import OSLog
import SwiftData
import UnwatchedShared

extension ChapterService {

    /// Brings a set of chapter rows in line with `desired`, reusing the rows that are already there.
    ///
    /// Rows are paired with the incoming chapters by position in start-time order, then updated in
    /// place; only a surplus row is deleted and only a missing one inserted. Reuse is the point:
    /// deleting a chapter that the player or a list row still holds leaves that reader with a row
    /// that traps on the next property read, and rebuilding the full list on every refresh made
    /// that easy to hit.
    ///
    /// A row that already matches is left untouched, so a hand-toggled `isActive` survives a
    /// refresh that changes nothing else — same as back when this replaced chapters wholesale.
    static func reconcileChapters(
        _ desired: [SendableChapter],
        with existing: [Chapter],
        in modelContext: ModelContext
    ) -> (chapters: [Chapter], hasChanges: Bool) {
        let existing = existing.sorted { $0.startTime < $1.startTime }
        var result = [Chapter]()
        result.reserveCapacity(desired.count)
        var hasChanges = false

        for (index, chapter) in desired.enumerated() {
            if index < existing.count {
                let row = existing[index]
                if !chapterEqual(chapter, row) {
                    Log.info("Update needed: \(row.description) vs \(chapter)")
                    overwrite(row, with: chapter)
                    hasChanges = true
                }
                result.append(row)
            } else {
                let row = chapter.getChapter
                modelContext.insert(row)
                result.append(row)
                hasChanges = true
            }
        }

        for surplus in existing.dropFirst(desired.count) {
            modelContext.delete(surplus)
            hasChanges = true
        }

        return (result, hasChanges)
    }

    /// Rewrites every field, matching what a freshly created `Chapter` would have carried.
    private static func overwrite(_ chapter: Chapter, with sendable: SendableChapter) {
        chapter.title = sendable.title
        chapter.startTime = sendable.startTime
        chapter.endTime = sendable.endTime
        chapter.duration = sendable.duration
        chapter.isActive = sendable.isActive
        chapter.category = sendable.category
        chapter.link = sendable.link
    }
}
