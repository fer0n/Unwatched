//
//  PodcastDownloadManager.swift
//  UnwatchedShared
//

import Foundation
import OSLog
import SwiftData

/// Keeps the next stretch of queued podcast episodes on disk, so they play without a connection.
@MainActor
@Observable
public final class PodcastDownloadManager {
    public static let shared = PodcastDownloadManager()

    /// Episodes with a download in flight, to keep `sync()` from restarting one.
    @ObservationIgnored private var downloadingIds = Set<String>()

    /// How far each in-flight episode has written, for the list item's progress bar.
    public private(set) var downloadProgress = [String: Double]()

    /// The episode that's playing, kept out of observation: it only steers the next `sync()`.
    @ObservationIgnored public var playingYoutubeId: String?

    /// Called once an episode's file is on disk.
    @ObservationIgnored public var onEpisodeDownloaded: (@MainActor (String) -> Void)?

    @ObservationIgnored private var backgroundEventsCompletion: (@Sendable () -> Void)?
    @ObservationIgnored private var scheduledSync: Task<Void, Never>?
    @ObservationIgnored private var isSyncing = false

    @ObservationIgnored private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Const.podcastDownloadSessionId)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: config, delegate: PodcastDownloadDelegate(), delegateQueue: nil)
    }()

    private init() { }

    /// Debounced `sync()`, for the many places the download window can shift from.
    public func scheduleSync() {
        guard PodcastDownloadStore.directory != nil else { return }
        scheduledSync?.cancel()
        scheduledSync = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await sync()
        }
    }

    public func sync() async {
        guard PodcastDownloadStore.directory != nil, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let defaults = UserDefaults.standard
        let playing = playingYoutubeId
        let plan = await PodcastDownloadActor().plan(
            limitHours: defaults.integer(forKey: Const.podcastDownloadLimitHours),
            keepDays: defaults.object(forKey: Const.podcastDownloadKeepDays) as? Int ?? 1,
            playing: playing
        )

        var inFlight = Set<String>()
        for task in await session.allTasks {
            guard let youtubeId = task.taskDescription else { continue }
            // an episode that started downloading on wifi terms has to be restarted once it's the one playing,
            // otherwise it sits idle on mobile data
            let isRestricted = youtubeId == playing && task.originalRequest?.allowsCellularAccess == false
            if plan.keep.contains(youtubeId), !isRestricted {
                inFlight.insert(youtubeId)
            } else {
                task.cancel()
            }
        }
        downloadingIds = inFlight
        downloadProgress = downloadProgress.filter { inFlight.contains($0.key) }
        PodcastDownloadStore.removeAll(except: plan.keep)
        setDownloaded(plan.cleared, to: nil)

        let onCellular = defaults.bool(forKey: Const.podcastDownloadOnCellular)
        for pending in plan.download where !inFlight.contains(pending.youtubeId) {
            start(pending, anyNetwork: onCellular || pending.youtubeId == playing)
        }
    }

    /// Touching `session` is what reconnects to the background session, so its delegate can deliver the events the
    /// app was woken for.
    public func handleBackgroundEvents(completion: @escaping @Sendable () -> Void) {
        backgroundEventsCompletion = completion
        _ = session
    }

    public func deleteAllDownloads() async {
        for task in await session.allTasks {
            task.cancel()
        }
        downloadingIds = []
        downloadProgress = [:]
        PodcastDownloadStore.removeAll(except: [])
        let context = DataProvider.mainContext
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.downloadedDate != nil })
        for video in (try? context.fetch(fetch)) ?? [] {
            video.downloadedDate = nil
        }
        try? context.save()
    }

    /// Written through the main context: a background actor's save doesn't reach the `Video` rows the lists already
    /// hold, so the indicator would sit stale until the next launch.
    private func setDownloaded(_ youtubeIds: [String], to date: Date?) {
        guard !youtubeIds.isEmpty else { return }
        let context = DataProvider.mainContext
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { youtubeIds.contains($0.youtubeId) })
        guard let videos = try? context.fetch(fetch), !videos.isEmpty else { return }
        for video in videos {
            video.downloadedDate = date
        }
        try? context.save()
    }

    private func start(_ pending: PendingPodcastDownload, anyNetwork: Bool) {
        var request = URLRequest(url: pending.url)
        request.allowsCellularAccess = anyNetwork
        request.allowsExpensiveNetworkAccess = anyNetwork
        request.allowsConstrainedNetworkAccess = anyNetwork
        let task = session.downloadTask(with: request)
        task.taskDescription = pending.youtubeId
        task.resume()
        downloadingIds.insert(pending.youtubeId)
    }

    fileprivate func didDownload(_ youtubeId: String) {
        setDownloaded([youtubeId], to: .now)
        onEpisodeDownloaded?(youtubeId)
    }

    /// A finished download holds a full bar for a moment before it's dropped, so the bar completes on screen instead
    /// of vanishing at whatever step it last reported.
    fileprivate func didFinish(_ youtubeId: String, succeeded: Bool) {
        downloadingIds.remove(youtubeId)
        guard succeeded, downloadProgress[youtubeId] != nil else {
            downloadProgress[youtubeId] = nil
            return
        }
        downloadProgress[youtubeId] = 1
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            guard !downloadingIds.contains(youtubeId) else { return }
            downloadProgress[youtubeId] = nil
        }
    }

    fileprivate func didWrite(_ youtubeId: String, _ fraction: Double) {
        let stepped = (fraction * 50).rounded(.down) / 50
        guard downloadProgress[youtubeId] != stepped else { return }
        downloadProgress[youtubeId] = stepped
    }

    fileprivate func didFinishBackgroundEvents() {
        backgroundEventsCompletion?()
        backgroundEventsCompletion = nil
    }
}

// MARK: - Session delegate

private final class PodcastDownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let youtubeId = downloadTask.taskDescription,
              let mediaUrl = downloadTask.originalRequest?.url,
              let destination = PodcastDownloadStore.fileUrl(youtubeId, mediaUrl) else {
            return
        }
        guard downloadTask.response?.isSuccessfulHttp != false else {
            Log.info("podcast download rejected: \(youtubeId)")
            return
        }
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            Log.error("podcast download failed to store: \(error.localizedDescription)")
            return
        }
        Task { @MainActor in
            PodcastDownloadManager.shared.didDownload(youtubeId)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let youtubeId = downloadTask.taskDescription, totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            PodcastDownloadManager.shared.didWrite(youtubeId, fraction)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let youtubeId = task.taskDescription else { return }
        if let error {
            Log.info("podcast download ended: \(error.localizedDescription)")
        }
        let succeeded = error == nil
        Task { @MainActor in
            PodcastDownloadManager.shared.didFinish(youtubeId, succeeded: succeeded)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            PodcastDownloadManager.shared.didFinishBackgroundEvents()
        }
    }
}

// MARK: - Planning

struct PendingPodcastDownload: Sendable {
    let youtubeId: String
    let url: URL
}

struct PodcastDownloadPlan: Sendable {
    /// Every episode whose file may stay on disk; anything else is swept.
    var keep = Set<String>()
    var download = [PendingPodcastDownload]()
    /// Episodes whose file is gone or about to be swept, so the flag has to follow.
    var cleared = [String]()
}

actor PodcastDownloadActor: SharedContextActor {
    /// Takes the playing episode, then walks the queue in play order until `limitHours` of unplayed time is covered,
    /// and decides what a watched episode's file has left.
    func plan(limitHours: Int, keepDays: Int, playing: String?) -> PodcastDownloadPlan {
        var plan = PodcastDownloadPlan()
        let enabled = limitHours != 0

        // first in line, and regardless of the ahead-of-time limit: what's playing is what has the most to lose from
        // a connection dropping mid-episode
        if let playing {
            let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == playing })
            if let video = (try? modelContext.fetch(fetch))?.first {
                add(video, to: &plan)
            }
        }

        if enabled {
            var budget = limitHours < 0 ? Double.infinity : Double(limitHours) * 3600
            let fetch = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order)])
            for entry in (try? modelContext.fetch(fetch)) ?? [] {
                guard budget > 0 else { break }
                guard let video = entry.video,
                      video.mediaUrl != nil,
                      video.watchedDate == nil else {
                    continue
                }
                budget -= video.remainingTime ?? video.duration ?? 0
                add(video, to: &plan)
            }
        }

        let expiry = Calendar.current.date(byAdding: .day, value: -keepDays, to: .now) ?? .now
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.downloadedDate != nil })
        for video in (try? modelContext.fetch(fetch)) ?? [] {
            if enabled, keepDays > 0, let watchedDate = video.watchedDate, watchedDate > expiry {
                plan.keep.insert(video.youtubeId)
            } else if !plan.keep.contains(video.youtubeId) {
                plan.cleared.append(video.youtubeId)
            }
        }
        return plan
    }

    private func add(_ video: Video, to plan: inout PodcastDownloadPlan) {
        guard let mediaUrl = video.mediaUrl, !plan.keep.contains(video.youtubeId) else { return }
        plan.keep.insert(video.youtubeId)
        guard PodcastDownloadStore.playbackUrl(for: video) == nil else { return }
        if video.downloadedDate != nil {
            plan.cleared.append(video.youtubeId)
        }
        plan.download.append(PendingPodcastDownload(youtubeId: video.youtubeId, url: mediaUrl))
    }
}

// MARK: - File store

public enum PodcastDownloadStore {
    /// `nil` where downloads aren't offered, which switches the whole feature off.
    public static let directory: URL? = {
        #if os(tvOS)
        return nil
        #else
        guard var url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        url.append(path: "PodcastDownloads", directoryHint: .isDirectory)
        guard (try? url.checkResourceIsReachable()) != true else {
            return url
        }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try url.setResourceValues(values)
        } catch {
            Log.error("podcast downloads unavailable: \(error.localizedDescription)")
            return nil
        }
        return url
        #endif
    }()

    /// Derived from the enclosure rather than stored, so writer and reader agree without a lookup.
    static func fileUrl(_ youtubeId: String, _ mediaUrl: URL) -> URL? {
        let fileExtension = mediaUrl.pathExtension
        return directory?.appending(path: youtubeId + "." + (fileExtension.isEmpty ? "mp3" : fileExtension))
    }

    public static func playbackUrl(for video: VideoData) -> URL? {
        guard video.downloadedDate != nil,
              let mediaUrl = video.mediaUrl,
              let url = fileUrl(video.youtubeId, mediaUrl),
              (try? url.checkResourceIsReachable()) == true else {
            return nil
        }
        return url
    }

    /// The downloaded file for an episode, found by name — for the callers that have the id but not the `Video` the
    /// enclosure's extension would come from.
    public static func downloadedFile(for youtubeId: String) -> URL? {
        contents().first {
            $0.deletingPathExtension().lastPathComponent == youtubeId && $0.pathExtension != "silence"
        }
    }

    static func removeAll(except keep: Set<String>) {
        for file in contents() where !keep.contains(file.deletingPathExtension().lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    public static func totalSize() -> Int64 {
        contents(keys: [.fileSizeKey]).reduce(0) {
            $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    private static func contents(keys: [URLResourceKey] = []) -> [URL] {
        guard let directory else { return [] }
        return (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys
        )) ?? []
    }
}
