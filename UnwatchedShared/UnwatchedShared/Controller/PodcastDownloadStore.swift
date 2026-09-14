//
//  PodcastDownloadStore.swift
//  UnwatchedShared
//

import Foundation
import OSLog

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
        guard let mediaUrl = video.mediaUrl,
              let url = fileUrl(video.youtubeId, mediaUrl),
              (try? url.checkResourceIsReachable()) == true else {
            return nil
        }
        return url
    }

    /// The downloaded file for an episode, found by name — for the callers that have the id but not the `Video` the
    /// enclosure's extension would come from.
    public static func downloadedFile(for youtubeId: String) -> URL? {
        episodeFiles().first { episodeId(of: $0) == youtubeId }
    }

    public static func downloadedIds() -> Set<String> {
        Set(episodeFiles().map(episodeId(of:)))
    }

    static func removeAll(except keep: Set<String>) {
        for file in contents() where !keep.contains(episodeId(of: file)) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func episodeFiles() -> [URL] {
        contents().filter { $0.pathExtension != "silence" }
    }

    private static func episodeId(of file: URL) -> String {
        file.deletingPathExtension().lastPathComponent
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
