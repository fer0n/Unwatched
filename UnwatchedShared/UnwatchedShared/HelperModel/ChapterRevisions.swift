//
//  ChapterRevisions.swift
//  UnwatchedShared
//

import Foundation
import Observation

/// Observable per-video counters for chapter edits SwiftData doesn't announce, see `Video.chaptersDidChange`.
public final class ChapterRevisions: @unchecked Sendable {
    public static let shared = ChapterRevisions()

    private let lock = NSLock()
    private var revisions = [String: Revision]()

    public subscript(youtubeId: String) -> Revision {
        lock.withLock {
            if let revision = revisions[youtubeId] {
                return revision
            }
            let revision = Revision()
            revisions[youtubeId] = revision
            return revision
        }
    }

    @Observable
    public final class Revision: @unchecked Sendable {
        public var value = 0
    }
}
