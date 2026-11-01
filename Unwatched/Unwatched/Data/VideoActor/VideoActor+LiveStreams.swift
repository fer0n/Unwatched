//
//  VideoActor+LiveStreams.swift
//  Unwatched
//

import Foundation
import SwiftData
import UnwatchedShared

extension VideoActor {
    func filterLiveStreams(_ videos: [SendableVideo], channelId: String?) async -> [SendableVideo] {
        guard let channelId, CloudKeyValueStore.hasPremium else {
            return videos
        }
        var liveIds = Set(UserDefaults.standard.stringArray(forKey: Const.hiddenLiveStreamIds) ?? [])
        let unchecked = videos.filter { $0.isYtShort != true && !liveIds.contains($0.youtubeId) }
        if !unchecked.isEmpty {
            do {
                let channelLiveIds = try await InnerTubeAPI().fetchChannelLiveStreamIds(channelId: channelId)
                let onLiveTab = unchecked.map(\.youtubeId).filter(channelLiveIds.contains)
                let found = await confirmedLiveStreams(onLiveTab)
                rememberLiveStreams(found)
                liveIds.formUnion(found)
            } catch {
                Log.refresh.warning("filterLiveStreams failed for \(channelId): \(error)")
            }
        }
        return videos.filter { !liveIds.contains($0.youtubeId) }
    }

    /// The Live tab also lists premieres; unconfirmed ids stay visible, since hidden videos are lost for good.
    private func confirmedLiveStreams(_ ids: [String]) async -> [String] {
        await withTaskGroup(of: String?.self) { group in
            for id in ids {
                group.addTask {
                    do {
                        let info = try await InnerTubeAPI().fetchVideoMetadata(videoId: id)
                        guard info.isLiveContent == true else {
                            Log.refresh.info("filterLiveStreams: \(id) is on the Live tab but not a stream")
                            return nil
                        }
                        return id
                    } catch {
                        Log.refresh.warning("filterLiveStreams: couldn't confirm \(id): \(error)")
                        return nil
                    }
                }
            }
            var confirmed = [String]()
            for await id in group {
                if let id { confirmed.append(id) }
            }
            return confirmed
        }
    }

    /// Hidden streams aren't stored, so they come back as new on every refresh.
    private func rememberLiveStreams(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        let known = UserDefaults.standard.stringArray(forKey: Const.hiddenLiveStreamIds) ?? []
        let updated = (known.filter { !ids.contains($0) } + ids).suffix(Const.hiddenLiveStreamIdsLimit)
        UserDefaults.standard.set(Array(updated), forKey: Const.hiddenLiveStreamIds)
    }
}
