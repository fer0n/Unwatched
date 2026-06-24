//
//  ScrubberThumbnails.swift
//  Unwatched
//
//  YouTube "storyboard" scrubbing preview thumbnails. YouTube serves these as sprite-sheet
//  JPEGs (grids of tiny frames). The recipe lives in the InnerTube player response under
//  `storyboards.playerStoryboardSpecRenderer.spec` (fetched via InnerTubeAPI+Storyboard).
//
//  This file owns the spec parser, an on-demand sheet downloader/cache, and the SwiftUI view
//  that renders the cropped frame while the user scrubs. Engine-agnostic: keyed only by
//  videoId + time, so it serves both the native AVPlayer and the WKWebView (custom-UI) player.
//

import SwiftUI
import UnwatchedShared
import ImageIO

// MARK: - Model

/// One storyboard quality level. YouTube ships 2–3 levels per video; higher levels have
/// larger frames (fewer per sheet). Field layout mirrors yt-dlp's `_extract_storyboard`.
struct StoryboardLevel {
    let level: Int
    let thumbWidth: Int
    let thumbHeight: Int
    /// Total frame count across every sheet of this level.
    let totalFrames: Int
    let cols: Int
    let rows: Int
    /// Replacement for the `$N` placeholder in the base URL.
    let nParam: String
    /// Per-level signature appended as `&sigh=`.
    let sigh: String

    var framesPerSheet: Int { max(1, cols * rows) }
}

/// A parsed `playerStoryboardSpecRenderer.spec` string.
///
/// Format: `|`-separated. The first segment is the base URL template (containing `$L` = level,
/// `$N` = level id, `$M` = sheet page). Each following segment describes a level as
/// `width#height#totalFrames#cols#rows#?#N#sigh`.
struct StoryboardSpec {
    let baseURL: String
    let levels: [StoryboardLevel]

    init?(spec: String) {
        let parts = spec.components(separatedBy: "|")
        guard parts.count >= 2 else { return nil }
        baseURL = parts[0]

        var parsed: [StoryboardLevel] = []
        for (index, raw) in parts.dropFirst().enumerated() {
            let f = raw.components(separatedBy: "#")
            guard
                f.count >= 8,
                let width = Int(f[0]), let height = Int(f[1]),
                let frames = Int(f[2]), let cols = Int(f[3]), let rows = Int(f[4]),
                width > 0, height > 0, frames > 0, cols > 0, rows > 0
            else { continue }
            parsed.append(
                StoryboardLevel(
                    level: index,
                    thumbWidth: width,
                    thumbHeight: height,
                    totalFrames: frames,
                    cols: cols,
                    rows: rows,
                    nParam: f[6],
                    sigh: f[7]
                )
            )
        }
        guard !parsed.isEmpty else { return nil }
        levels = parsed
    }

    /// Highest-resolution level available (clearest preview).
    var preferredLevel: StoryboardLevel? {
        levels.max { $0.thumbWidth < $1.thumbWidth }
    }

    /// Maps a playback time to the sheet + crop rect holding that frame.
    /// Frame interval is derived from the video duration (more robust than the spec's own
    /// interval field, which is ignored here — matching yt-dlp).
    func tile(at seconds: Double, duration: Double) -> StoryboardTile? {
        guard duration > 0, let level = preferredLevel else { return nil }

        let clamped = min(max(seconds, 0), duration)
        let frameIndex = min(
            max(Int(clamped / duration * Double(level.totalFrames)), 0),
            level.totalFrames - 1
        )
        let perSheet = level.framesPerSheet
        let sheetIndex = frameIndex / perSheet
        let inSheet = frameIndex % perSheet
        let col = inSheet % level.cols
        let row = inSheet / level.cols

        let urlString = baseURL
            .replacingOccurrences(of: "$L", with: String(level.level))
            .replacingOccurrences(of: "$N", with: level.nParam)
            .replacingOccurrences(of: "$M", with: String(sheetIndex))
            + "&sigh=" + level.sigh
        guard let url = URL(string: urlString) else { return nil }

        let rect = CGRect(
            x: col * level.thumbWidth,
            y: row * level.thumbHeight,
            width: level.thumbWidth,
            height: level.thumbHeight
        )
        return StoryboardTile(
            frameIndex: frameIndex,
            sheetURL: url,
            cropRect: rect,
            size: CGSize(width: level.thumbWidth, height: level.thumbHeight)
        )
    }
}

/// A single resolved preview frame: which sprite sheet to download and where to crop it.
struct StoryboardTile: Equatable {
    let frameIndex: Int
    let sheetURL: URL
    let cropRect: CGRect
    let size: CGSize
}

// MARK: - Provider

/// Loads the storyboard spec for the current video and serves cropped preview frames on
/// demand, caching downloaded sheets so scrubbing within a sheet costs nothing.
@Observable @MainActor
final class ScrubberThumbnailProvider {
    /// Shared instance so every scrubber (overlay + inline bars) reuses one storyboard fetch
    /// and one sheet cache for the current video.
    static let shared = ScrubberThumbnailProvider()

    private let api = InnerTubeAPI()
    private(set) var spec: StoryboardSpec?

    // MARK: Live scrub state (shared by every scrubber → one preview over the video)

    /// The time currently targeted by an active scrub, nil when idle.
    var previewTime: Double?
    /// Whether any scrubber is currently being dragged.
    var isScrubbing = false

    /// Whether the full-bleed preview should be shown over the video right now.
    var showThumbnail: Bool {
        isScrubbing && previewTime != nil && spec != nil
    }

    func endScrubbing() {
        isScrubbing = false
        previewTime = nil
    }

    private var loadedVideoId: String?
    private var loadTask: Task<Void, Never>?

    /// Decoded sprite sheets, bounded by total decoded-pixel cost. `NSCache` also evicts
    /// automatically under memory pressure, so scrubbing a long video can't pin unbounded RAM.
    private let sheetCache: NSCache<NSURL, CGImage> = {
        let cache = NSCache<NSURL, CGImage>()
        cache.totalCostLimit = 64 * 1024 * 1024 // ~64 MB of decoded sheets
        return cache
    }()

    /// Fetches the storyboard spec for `videoId` (no-op if already loaded). Pass nil to clear.
    func load(videoId: String?) {
        guard let videoId else { reset(); return }
        guard videoId != loadedVideoId else { return }
        reset()
        loadedVideoId = videoId
        Log.info("[Storyboard] loading for \(videoId)")
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let spec = try await self.api.fetchStoryboard(videoId: videoId)
                guard !Task.isCancelled, self.loadedVideoId == videoId else { return }
                self.spec = spec
                if let level = spec?.preferredLevel {
                    Log.info("[Storyboard] ready for \(videoId): \(spec?.levels.count ?? 0) level(s); "
                        + "using \(level.thumbWidth)x\(level.thumbHeight), \(level.totalFrames) frames, "
                        + "grid \(level.cols)x\(level.rows)")
                } else {
                    Log.warning("[Storyboard] no usable spec for \(videoId)")
                }
            } catch {
                guard !Task.isCancelled else { return }
                Log.error("[Storyboard] fetch failed for \(videoId): \(error.localizedDescription)")
            }
        }
    }

    private func reset() {
        loadTask?.cancel()
        loadTask = nil
        spec = nil
        loadedVideoId = nil
        sheetCache.removeAllObjects()
    }

    func tile(at seconds: Double, duration: Double) -> StoryboardTile? {
        spec?.tile(at: seconds, duration: duration)
    }

    /// Returns the cropped frame for a tile, downloading and caching its sheet if needed.
    func image(for tile: StoryboardTile) async -> CGImage? {
        let key = tile.sheetURL as NSURL
        let sheet: CGImage
        if let cached = sheetCache.object(forKey: key) {
            sheet = cached
        } else {
            guard let downloaded = await Self.downloadImage(tile.sheetURL) else {
                Log.error("[Storyboard] sheet download/decode failed: \(tile.sheetURL.absoluteString)")
                return nil
            }
            if Task.isCancelled { return nil }
            sheetCache.setObject(downloaded, forKey: key, cost: downloaded.width * downloaded.height * 4)
            Log.info("[Storyboard] downloaded sheet \(downloaded.width)x\(downloaded.height): \(tile.sheetURL.lastPathComponent)")
            sheet = downloaded
        }
        // The final sheet of a level is often partially filled — guard the crop rect.
        let bounds = CGRect(x: 0, y: 0, width: sheet.width, height: sheet.height)
        guard bounds.contains(tile.cropRect) else {
            Log.warning("[Storyboard] crop \(tile.cropRect.debugDescription) out of bounds for "
                + "sheet \(sheet.width)x\(sheet.height) (frame \(tile.frameIndex))")
            return nil
        }
        return sheet.cropping(to: tile.cropRect)
    }

    /// `nonisolated` so the network wait *and* the JPEG decode run off the main actor.
    /// `kCGImageSourceShouldCacheImmediately` forces the pixel decode here (in the background)
    /// rather than lazily on the main thread at first render, which would jank scrubbing.
    nonisolated private static func downloadImage(_ url: URL) async -> CGImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        return CGImageSourceCreateImageAtIndex(source, 0, options)
    }
}

// MARK: - View

/// Renders the storyboard frame for the current scrub time, filling its container (used as a
/// full-bleed preview over the video while scrubbing). Recomputes only when the target frame
/// changes (via `.task(id:)`), so dragging within one frame's interval is free.
struct ScrubberThumbnailView: View {
    let provider: ScrubberThumbnailProvider
    let time: Double?
    let duration: Double?

    @State private var image: CGImage?

    private var tile: StoryboardTile? {
        guard let time, let duration else { return nil }
        return provider.tile(at: time, duration: duration)
    }

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.medium)
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Transparent until the first frame loads, so the live video shows through.
                    Color.clear
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .task(id: tile) {
            guard let tile else { return }
            if let cropped = await provider.image(for: tile) {
                image = cropped
            }
        }
    }
}

