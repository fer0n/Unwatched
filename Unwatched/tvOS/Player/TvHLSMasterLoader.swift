//
//  TvHLSMasterLoader.swift
//  UnwatchedTV
//

import AVFoundation
import UnwatchedShared

/// Hands AVPlayer the VISIONOS client's HLS master with everything Apple TV can't decode removed.
///
/// That master mixes an H.264 ladder (up to 1080p) with VP9 variants up to 4K, and AVPlayer will
/// pick a VP9 one and fail. Only the master passes through here: the variant playlists it lists are
/// absolute https URLs, so AVPlayer loads those and every segment directly.
final class TvHLSMasterLoader: NSObject, AVAssetResourceLoaderDelegate {
    /// The resource loader holds its delegate weakly, so one instance lives for the app.
    private static let shared = TvHLSMasterLoader()
    private static let scheme = "unwatched-hls"
    private let queue = DispatchQueue(label: "TvHLSMasterLoader")

    static func asset(for master: URL) -> AVURLAsset? {
        guard var components = URLComponents(url: master, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = scheme
        guard let url = components.url else { return nil }
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(shared, queue: shared.queue)
        return asset
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let url = loadingRequest.request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == Self.scheme else {
            return false
        }
        components.scheme = "https"
        guard let master = components.url else { return false }

        URLSession.app.dataTask(with: master) { data, response, error in
            if let error {
                loadingRequest.finishLoading(with: error)
                return
            }
            guard let data, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                loadingRequest.finishLoading(with: URLError(.badServerResponse, userInfo: ["status": status]))
                return
            }
            let filtered = Data(filterHLSMasterManifest(
                String(decoding: data, as: UTF8.self),
                maximumHeight: InnerTubeClients.VisionOS.maximumHLSHeight,
                requiredVideoCodec: "avc1"
            ).utf8)
            if let info = loadingRequest.contentInformationRequest {
                // A UTI, not a MIME type — AVFoundation misreads the playlist otherwise.
                info.contentType = "public.m3u-playlist"
                info.contentLength = Int64(filtered.count)
                info.isByteRangeAccessSupported = false
            }
            loadingRequest.dataRequest?.respond(with: filtered)
            loadingRequest.finishLoading()
        }.resume()
        return true
    }
}
