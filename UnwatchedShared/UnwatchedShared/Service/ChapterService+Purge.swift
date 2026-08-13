//
//  ChapterService+Purge.swift
//  UnwatchedShared
//

import Foundation
import OSLog
import SwiftData

public extension ChapterService {

    /// Sheds the `Chapter` rows a library built before chapters were derived is still carrying.
    /// Once per install, and safe to re-run if it's interrupted — the flag is only set once it's
    /// through, and a second call while one is in flight is dropped rather than made to race the
    /// first over the same rows.
    static func purgeDerivableChaptersIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Const.didPurgeDerivableChapters),
              chapterPurgeGate.enter() else {
            return
        }
        Task.detached {
            let actor = ChapterPurgeActor()
            if await actor.purgeDerivableChapters() != nil {
                UserDefaults.standard.set(true, forKey: Const.didPurgeDerivableChapters)
            }
            chapterPurgeGate.leave()
        }
    }
}

/// Lets one purge through at a time. Callers come from a refresh, which can start again while the
/// previous purge is still walking the library.
final class PurgeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isRunning = false

    func enter() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isRunning else { return false }
        isRunning = true
        return true
    }

    func leave() {
        lock.lock()
        isRunning = false
        lock.unlock()
    }
}

let chapterPurgeGate = PurgeGate()

actor ChapterPurgeActor: SharedContextActor {

    /// Drops `Chapter` rows that re-parsing the video's description reproduces exactly.
    ///
    /// Chapters used to be stored for every video the feed brought in — a row each, and with
    /// iCloud sync on, a CKRecord each. They're parsed on demand now
    /// (`ChapterService.derivedChapters`), which leaves libraries built before that carrying tens
    /// of thousands of records saying nothing the description doesn't.
    ///
    /// Only exact matches go. A chapter whose title, timing or category differs from the parse is
    /// something the user renamed, retimed or added, and a set the parse can't reproduce in full
    /// stays whole — a video keeps all its rows or none, never half. `isActive` is deliberately
    /// not compared: the parse applies the same skip filter, so a chapter switched off by that is
    /// still reproducible, while one switched off by hand differs in nothing else and would be
    /// lost. Which is why this only ever looks at `chapters`, never `mergedChapters` — no
    /// description reproduces a SponsorBlock merge.
    ///
    /// Nothing is dropped on incomplete data: a video mid-import, whose description hasn't
    /// arrived or whose rows have only partly landed, fails the comparison and is left alone.
    ///
    /// `nil` when it couldn't get at the library at all, so the caller knows not to mark the purge
    /// as done — the whole library is still to walk, not zero rows' worth of it.
    func purgeDerivableChapters() -> Int? {
        let fetch = FetchDescriptor<Video>()
        guard let videos = try? modelContext.fetch(fetch) else {
            Log.error("purgeDerivableChapters: couldn't fetch videos")
            return nil
        }

        var deletedCount = 0
        for video in videos {
            let rows = (video.chapters ?? []).sorted { $0.startTime < $1.startTime }
            guard !rows.isEmpty, isDerivable(rows, of: video) else { continue }

            // clearing the relationship matters as much as the delete: leaving it listing gone
            // rows lets a reader pick one up and trap on it later
            video.chapters = []
            for row in rows {
                modelContext.delete(row)
            }
            deletedCount += rows.count
        }

        if deletedCount > 0 {
            do {
                try modelContext.save()
            } catch {
                // the rows are still there, so let the next launch try again
                Log.error("purgeDerivableChapters: \(error)")
                return nil
            }
        }
        Log.info("purgeDerivableChapters: removed \(deletedCount) chapters")
        return deletedCount
    }

    private func isDerivable(_ rows: [Chapter], of video: Video) -> Bool {
        guard let description = video.videoDescription, !description.isEmpty else {
            return false
        }
        let parsed = ChapterService
            .extractChapters(from: description, videoDuration: video.duration)
            .sorted { $0.startTime < $1.startTime }

        guard parsed.count == rows.count else { return false }
        return zip(parsed, rows).allSatisfy { ChapterService.chapterEqual($0, $1) }
    }
}
