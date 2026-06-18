#if !os(macOS)
import Foundation
import os

private let wkHLSLog = Logger(subsystem: appSubsystem, category: "WKHLSManager")
private let wkHLSDefaultsKey = "wkHLSCache"

// MARK: - WKHLSManager

/// Owns the URL cache and pre-fetch logic for WKWebView-extracted HLS streams.
/// Kept separate from YouTubeWebViewHLSExtractor (a SmartTubeIOS source file)
/// so that file stays close to upstream and is easy to merge.
@MainActor
final class WKHLSManager {

    static let shared = WKHLSManager()

    /// Desktop Safari UA used for all WKWebView-extracted HLS requests.
    /// Must match the UA set on the hidden WKWebView in YouTubeWebViewHLSExtractor.
    static let desktopSafariUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"

    // MARK: - Cache

    struct CachedHLS {
        let url: URL
        let nSolver: (unsolved: String, solved: String)?
        let poToken: String?
    }

    // Named tuples aren't Codable; this flat struct is used only for UserDefaults persistence.
    private struct PersistedEntry: Codable {
        let urlString: String
        let nUnsolved: String?
        let nSolved: String?
        let poToken: String?
    }

    private var cache: [String: CachedHLS] = [:]

    init() {
        loadFromDisk()
    }

    func store(url: URL, nSolver: (unsolved: String, solved: String)?, poToken: String? = nil, for videoId: String) {
        cache[videoId] = CachedHLS(url: url, nSolver: nSolver, poToken: poToken)
        saveToDisk()
        let expStr = Self.expiryDate(from: url).map { "expire=\(Int($0.timeIntervalSince1970))" } ?? "no expire"
        wkHLSLog.notice("✅ [cache] stored \(videoId as NSString) \(expStr as NSString)")
    }

    /// Returns a cached entry if it exists and won't expire for at least 5 minutes.
    /// Expiry is parsed from the `expire=` Unix timestamp in the signed URL — no network needed.
    func validEntry(for videoId: String) -> CachedHLS? {
        guard let entry = cache[videoId] else { return nil }
        if let expiry = Self.expiryDate(from: entry.url), expiry > Date(timeIntervalSinceNow: 300) {
            return entry
        }
        cache.removeValue(forKey: videoId)
        saveToDisk()
        return nil
    }

    private static func expiryDate(from url: URL) -> Date? {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let expStr = items.first(where: { $0.name == "expire" })?.value,
              let ts = Double(expStr) else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: wkHLSDefaultsKey),
              let raw = try? JSONDecoder().decode([String: PersistedEntry].self, from: data) else { return }
        let cutoff = Date(timeIntervalSinceNow: 300)
        var loaded = 0
        for (videoId, entry) in raw {
            guard let url = URL(string: entry.urlString) else { continue }
            // Skip entries already expired (or expiring within 5 min) — no need to persist them.
            if let expiry = Self.expiryDate(from: url), expiry <= cutoff { continue }
            let nSolver: (unsolved: String, solved: String)?
            if let u = entry.nUnsolved, let s = entry.nSolved { nSolver = (u, s) } else { nSolver = nil }
            cache[videoId] = CachedHLS(url: url, nSolver: nSolver, poToken: entry.poToken)
            loaded += 1
        }
        wkHLSLog.notice("[cache] loaded \(loaded) valid entries from disk")
    }

    private func saveToDisk() {
        let cutoff = Date(timeIntervalSinceNow: 300)
        var raw: [String: PersistedEntry] = [:]
        for (videoId, entry) in cache {
            // Only persist entries that will still be valid after a relaunch.
            if let expiry = Self.expiryDate(from: entry.url), expiry <= cutoff { continue }
            raw[videoId] = PersistedEntry(
                urlString: entry.url.absoluteString,
                nUnsolved: entry.nSolver?.unsolved,
                nSolved: entry.nSolver?.solved,
                poToken: entry.poToken
            )
        }
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: wkHLSDefaultsKey)
        }
    }

    // MARK: - Pre-fetch

    /// Proactively extracts and caches the HLS URL for `videoId` while a different
    /// video is already playing. Call only when the current extraction is idle
    /// (i.e. after the current video's readyToPlay fires).
    func preExtract(_ videoId: String) async {
        guard validEntry(for: videoId) == nil else {
            wkHLSLog.notice("[prefetch] already cached: \(videoId as NSString)")
            return
        }
        wkHLSLog.notice("[prefetch] starting: \(videoId as NSString)")
        guard let url = await YouTubeWebViewHLSExtractor.shared.extractHLSURL(videoId: videoId) else {
            wkHLSLog.notice("[prefetch] nil result: \(videoId as NSString)")
            return
        }
        let nSolver = YouTubeWebViewHLSExtractor.shared.extractedNSolver
        let pot = YouTubeWebViewHLSExtractor.shared.extractedPoToken
        store(url: url, nSolver: nSolver, poToken: pot, for: videoId)
        wkHLSLog.notice("✅ [prefetch] done: \(videoId as NSString)")
    }
}
#endif // !os(macOS)
