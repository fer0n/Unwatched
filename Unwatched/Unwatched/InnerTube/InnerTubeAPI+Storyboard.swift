//
//  InnerTubeAPI+Storyboard.swift
//  Unwatched
//
//  Unwatched-owned extension (not part of the upstream SmartTube sync). Fetches only the
//  storyboard spec from the InnerTube player endpoint — the sprite-sheet recipe YouTube uses
//  to render scrubbing preview thumbnails. Independent of stream resolution, so it works for
//  both the native AVPlayer and the WKWebView (custom-UI) player.
//

import Foundation
import UnwatchedShared

extension InnerTubeAPI {

    /// Fetches a video's storyboard spec from the InnerTube player endpoint
    /// (`storyboards.playerStoryboardSpecRenderer.spec`). This is the only field read, so it
    /// succeeds independently of whether playable streams can be resolved. Returns nil when
    /// the video has no storyboards (e.g. very short clips or some live streams).
    func fetchStoryboard(videoId: String) async throws -> StoryboardSpec? {
        // iOS body + iOS headers (matching `postPlayer`). The iOS player response includes
        // `storyboards`; the web client returns UNPLAYABLE without a PO token / auth.
        var body = makeBody(client: iosClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await postPlayer(body: body)
        guard let storyboards = data["storyboards"] as? [String: Any] else {
            let status = (data["playabilityStatus"] as? [String: Any])?["status"] as? String ?? "?"
            Log.info("[Storyboard] \(videoId): response has no `storyboards` field "
                + "(playabilityStatus=\(status); top keys: \(data.keys.sorted().joined(separator: ", ")))")
            return nil
        }
        guard
            let renderer = storyboards["playerStoryboardSpecRenderer"] as? [String: Any],
            let spec = renderer["spec"] as? String
        else {
            Log.info("[Storyboard] \(videoId): no playerStoryboardSpecRenderer.spec "
                + "(storyboards keys: \(storyboards.keys.sorted().joined(separator: ", ")))")
            return nil
        }
        guard let parsed = StoryboardSpec(spec: spec) else {
            Log.error("[Storyboard] \(videoId): failed to parse spec: \(spec.prefix(200))")
            return nil
        }
        return parsed
    }
}
