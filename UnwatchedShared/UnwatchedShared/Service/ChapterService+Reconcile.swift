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
    /// Rows are paired with the incoming chapters by start time, then by position, and updated in
    /// place; only surplus is deleted. Reuse is the point: a deleted chapter that the player or a
    /// list row still holds traps that reader on its next property read, and an untouched row
    /// keeps a hand-toggled `isActive` through a refresh that changes nothing else.
    ///
    /// No context to pass: rows have to be created in the video's own, relating them across
    /// contexts is a SwiftData fatal error.
    @discardableResult
    public static func reconcileChapters(
        _ desired: [SendableChapter],
        for video: Video,
        merged: Bool = false
    ) -> (chapters: [Chapter], hasChanges: Bool) {
        guard let modelContext = video.modelContext else {
            Log.warning("reconcileChapters: video has no context")
            return ([], false)
        }
        let desired = desired.sorted { $0.startTime < $1.startTime }
        let existing = attachedRows(of: video, merged: merged, in: modelContext)
        let paired = pairRows(existing, with: desired)
        var result = [Chapter]()
        result.reserveCapacity(desired.count)
        var hasChanges = false

        for (chapter, row) in zip(desired, paired) {
            if let row {
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

        let kept = Set(result.map(ObjectIdentifier.init))
        for surplus in existing where !kept.contains(ObjectIdentifier(surplus)) {
            modelContext.delete(surplus)
            hasChanges = true
        }

        if hasChanges {
            attach(result, to: video, merged: merged)
            // rows reused in place are edited, not re-attached: see `Video.chapterRevision`
            video.chaptersDidChange()
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

    private static func attachedRows(of video: Video, merged: Bool, in context: ModelContext) -> [Chapter] {
        // the relationship misses rows another context attached, and a second set would orphan them
        let youtubeId = video.youtubeId
        let descriptor = merged
            ? FetchDescriptor<Chapter>(predicate: #Predicate { $0.mergedChapterVideo?.youtubeId == youtubeId })
            : FetchDescriptor<Chapter>(predicate: #Predicate { $0.video?.youtubeId == youtubeId })
        let stored = ((try? context.fetch(descriptor)) ?? []).filter {
            (merged ? $0.mergedChapterVideo : $0.video) === video
        }
        var rows = (merged ? video.mergedChapters : video.chapters) ?? []
        let known = Set(rows.map(ObjectIdentifier.init))
        rows += stored.filter { !known.contains(ObjectIdentifier($0)) }
        return rows.sorted { $0.startTime < $1.startTime }
    }

    private static func pairRows(_ rows: [Chapter], with desired: [SendableChapter]) -> [Chapter?] {
        var unclaimed = rows
        var paired = desired.map { chapter -> Chapter? in
            guard let index = unclaimed.firstIndex(where: { $0.startTime == chapter.startTime }) else {
                return nil
            }
            return unclaimed.remove(at: index)
        }
        for index in paired.indices where paired[index] == nil && !unclaimed.isEmpty {
            paired[index] = unclaimed.removeFirst()
        }
        return paired
    }

    /// Compared as a set: a relationship hands its contents back in no particular order.
    private static func sameRows(_ current: [Chapter]?, _ chapters: [Chapter]) -> Bool {
        guard let current, current.count == chapters.count else { return false }
        return Set(current.map(ObjectIdentifier.init)) == Set(chapters.map(ObjectIdentifier.init))
    }

    /// Rewrites every field a freshly created `Chapter` would have carried, except `order`: rows are
    /// paired by position, so a refresh leaves the slot the user dragged this one into alone.
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
