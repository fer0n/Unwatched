//
//  VideoActor+LiveStreams.swift
//  Unwatched
//

import Foundation
import SwiftData
import UnwatchedShared

extension VideoActor {
    func filterLiveStreams(
        _ videos: [SendableVideo],
        _ sub: Subscription,
        hideByDefault: Bool
    ) async -> [SendableVideo] {
        guard !sub.isPodcast,
              let channelId = sub.youtubeChannelId,
              sub.liveStreamSetting.shouldHide(hideByDefault),
              CloudKeyValueStore.hasPremium else {
            return videos
        }
        var liveIds = Set(UserDefaults.standard.stringArray(forKey: Const.hiddenLiveStreamIds) ?? [])
        let unchecked = videos.filter { $0.isYtShort != true && !liveIds.contains($0.youtubeId) }
        if !unchecked.isEmpty {
            do {
                let channelLiveIds = try await InnerTubeAPI().fetchChannelLiveStreamIds(channelId: channelId)
                let found = unchecked.map(\.youtubeId).filter(channelLiveIds.contains)
                rememberLiveStreams(found)
                liveIds.formUnion(found)
            } catch {
                Log.warning("filterLiveStreams failed for \(channelId): \(error)")
            }
        }
        return videos.filter { !liveIds.contains($0.youtubeId) }
    }

    /// Hidden streams aren't stored, so they come back as new on every refresh.
    private func rememberLiveStreams(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        let known = UserDefaults.standard.stringArray(forKey: Const.hiddenLiveStreamIds) ?? []
        let updated = (known.filter { !ids.contains($0) } + ids).suffix(Const.hiddenLiveStreamIdsLimit)
        UserDefaults.standard.set(Array(updated), forKey: Const.hiddenLiveStreamIds)
    }
}
