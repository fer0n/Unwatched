//
//  SearchVM+Status.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import UnwatchedShared

/// Keeps the Search tab's rows in sync with the store: results start out as plain
/// `SendableVideo`s (nothing is persisted until the user acts on one), so their
/// inbox/queue/watched badges have to be overlaid from what's actually stored.
extension SearchVM {
    /// Refreshes a single result's inbox/queue/watched status from the store after an
    /// action (e.g. adding to the queue). If the video has since been persisted, its
    /// `SendableVideo` is swapped for the stored one so `VideoListItem` shows the badge.
    func refreshStatus(for youtubeId: String) {
        guard let updated = Self.storedStatus(for: youtubeId) else { return }
        apply([youtubeId: updated])
    }

    /// Overlays stored status onto all current results (e.g. items already in the
    /// queue/inbox, or after returning from playback).
    func refreshAllStatuses() {
        let youtubeIds = (results + localResults.bookmarks + localResults.videos).map(\.youtubeId)
        guard !youtubeIds.isEmpty else { return }
        let stored = Self.storedStatuses(for: youtubeIds)
        guard !stored.isEmpty else { return }
        apply(stored)
    }

    /// Swaps in the stored version of every result it has an entry for, across the
    /// YouTube and the local video lists.
    private func apply(_ stored: [String: SendableVideo]) {
        withAnimation {
            if let updated = Self.applying(stored, to: results) {
                results = updated
            }
            if let updated = Self.applying(stored, to: localResults.bookmarks) {
                localResults.bookmarks = updated
            }
            if let updated = Self.applying(stored, to: localResults.videos) {
                localResults.videos = updated
            }
        }
    }

    /// `nil` when nothing changed, so untouched lists aren't reassigned (which would
    /// invalidate the views observing them for no reason).
    private static func applying(
        _ stored: [String: SendableVideo],
        to videos: [SendableVideo]
    ) -> [SendableVideo]? {
        var updated = videos
        var didChange = false
        for index in updated.indices {
            if let match = stored[updated[index].youtubeId], match != updated[index] {
                updated[index] = match
                didChange = true
            }
        }
        return didChange ? updated : nil
    }

    private static func storedStatus(for youtubeId: String) -> SendableVideo? {
        let context = DataProvider.mainContext
        guard let video = VideoService.getVideo(for: youtubeId, modelContext: context) else {
            return nil
        }
        return video.toExportWithSubscription ?? video.toExport
    }

    /// Fetches stored status for many videos in a single query, keyed by `youtubeId`.
    private static func storedStatuses(for youtubeIds: [String]) -> [String: SendableVideo] {
        let context = DataProvider.mainContext
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { youtubeIds.contains($0.youtubeId) })
        guard let videos = try? context.fetch(fetch) else { return [:] }
        return Dictionary(
            videos.compactMap { video -> (String, SendableVideo)? in
                guard let export = video.toExportWithSubscription ?? video.toExport else { return nil }
                return (video.youtubeId, export)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
