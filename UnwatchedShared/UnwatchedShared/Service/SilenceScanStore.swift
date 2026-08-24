//
//  SilenceScanStore.swift
//  UnwatchedShared
//

import AVFoundation
import Foundation
import OSLog

/// Keeps one scan per downloaded episode, next to the download itself.
enum SilenceScanStore {
    static func url(for youtubeId: String) -> URL? {
        PodcastDownloadStore.directory?.appending(path: youtubeId + ".silence")
    }

    /// Nil for a scan written before `Const.silenceScanVersion`, which is what gets it re-scanned.
    static func read(_ youtubeId: String) -> SilenceScan? {
        guard let url = url(for: youtubeId), let data = try? Data(contentsOf: url) else { return nil }
        guard let scan = try? JSONDecoder().decode(SilenceScan.self, from: data) else { return nil }
        return scan.version == Const.silenceScanVersion ? scan : nil
    }

    static func write(_ scan: SilenceScan, for youtubeId: String) {
        guard let url = url(for: youtubeId) else { return }
        do {
            try JSONEncoder().encode(scan).write(to: url, options: .atomic)
        } catch {
            Log.error("silence scan not saved: \(error.localizedDescription)")
        }
    }
}

/// Runs the scans and hands out their results.
public actor SilenceScanActor {
    public static let shared = SilenceScanActor()

    private var running: [String: Task<SilenceScan?, Never>] = [:]

    private init() { }

    /// The scan for an episode, or nil when there isn't one yet. Never waits for a scan to finish.
    public static func existing(for video: VideoData) -> SilenceScan? {
        guard PodcastDownloadStore.playbackUrl(for: video) != nil else { return nil }
        return SilenceScanStore.read(video.youtubeId)
    }

    /// Scans the downloaded episode unless it already has a scan or one is already running.
    @discardableResult
    public func scanIfNeeded(youtubeId: String, url: URL) async -> SilenceScan? {
        if let existing = SilenceScanStore.read(youtubeId) {
            return existing
        }
        if let running = running[youtubeId] {
            return await running.value
        }
        let task = Task<SilenceScan?, Never>.detached(priority: .utility) {
            do {
                let scan = try await SilenceScanner.scan(url: url)
                SilenceScanStore.write(scan, for: youtubeId)
                return scan
            } catch {
                Log.warning("silence scan failed for \(youtubeId): \(error.localizedDescription)")
                return nil
            }
        }
        running[youtubeId] = task
        let scan = await task.value
        running[youtubeId] = nil
        return scan
    }

    /// Called when a download lands.
    public nonisolated static func scanDownloadedEpisode(youtubeId: String) {
        guard UserDefaults.standard.bool(forKey: Const.trimSilence),
              let url = PodcastDownloadStore.downloadedFile(for: youtubeId) else {
            return
        }
        scanInBackground(youtubeId: youtubeId, url: url)
    }

    /// Fire-and-forget, for the places that only want the scan to exist by next time.
    public nonisolated static func scanInBackground(youtubeId: String, url: URL) {
        Task.detached(priority: .utility) {
            await shared.scanIfNeeded(youtubeId: youtubeId, url: url)
        }
    }
}
