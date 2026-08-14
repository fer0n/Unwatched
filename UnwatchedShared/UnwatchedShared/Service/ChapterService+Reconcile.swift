//
//  ChapterService+Reconcile.swift
//  UnwatchedShared
//

import Foundation
import OSLog
import SwiftData

extension ChapterService {

    /// Brings a video's chapter rows in line with `desired`, reusing the rows already there and
    /// attaching whatever it ends up with.
    ///
    /// Rows are paired with the incoming chapters by position in start-time order and updated in
    /// place; only surplus is deleted. Reuse is the point: a deleted chapter that the player or a
    /// list row still holds traps that reader on its next property read, and an untouched row
    /// keeps a hand-toggled `isActive` through a refresh that changes nothing else.
    @discardableResult
    public static func reconcileChapters(
        _ desired: [SendableChapter],
        for video: Video,
        merged: Bool = false,
        in modelContext: ModelContext
    ) -> (chapters: [Chapter], hasChanges: Bool) {
        let desired = desired.sorted { $0.startTime < $1.startTime }
        let existing = (merged ? video.mergedChapters : video.chapters) ?? []
        let sorted = existing.sorted { $0.startTime < $1.startTime }
        var result = [Chapter]()
        result.reserveCapacity(desired.count)
        var hasChanges = false

        for (index, chapter) in desired.enumerated() {
            if index < sorted.count {
                let row = sorted[index]
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

        for surplus in sorted.dropFirst(desired.count) {
            modelContext.delete(surplus)
            hasChanges = true
        }

        if hasChanges {
            attach(result, to: video, merged: merged)
        }
        return (result, hasChanges)
    }

    /// Hands a video its chapter rows, setting both sides. Rows only written where they differ:
    /// reassigning the same video is a CKRecord push per row on every toggle.
    ///
    /// Row side first — the array assignment fills `Chapter.video` in through the inverse, and a
    /// check after it skips every row, leaving only the write that doesn't reach CloudKit.
    /// See `testAssigningTheArrayAlsoFillsInTheRowSide`.
    public static func attach(_ chapters: [Chapter], to video: Video, merged: Bool = false) {
        let ownSide: ReferenceWritableKeyPath<Video, [Chapter]?> = merged ? \.mergedChapters : \.chapters
        let rowSide: ReferenceWritableKeyPath<Chapter, Video?> = merged ? \.mergedChapterVideo : \.video

        for chapter in chapters where chapter[keyPath: rowSide] !== video {
            chapter[keyPath: rowSide] = video
        }
        if !sameRows(video[keyPath: ownSide], chapters) {
            video[keyPath: ownSide] = chapters
        }
    }

    /// Compared as a set: a relationship hands its contents back in no particular order.
    private static func sameRows(_ current: [Chapter]?, _ chapters: [Chapter]) -> Bool {
        guard let current, current.count == chapters.count else { return false }
        return Set(current.map(ObjectIdentifier.init)) == Set(chapters.map(ObjectIdentifier.init))
    }

    /// Rewrites every field a freshly created `Chapter` would have carried.
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
