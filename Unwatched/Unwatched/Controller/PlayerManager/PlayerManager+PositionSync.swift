//
//  PlayerManager+PositionSync.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

extension PlayerManager {
    @MainActor
    func applyRemotePosition(seek: Bool = true) {
        guard !isPlaying,
              let video,
              let seconds = PlaybackPositionSync.shared.takeRemotePosition(for: video.youtubeId),
              abs(seconds - (currentTime ?? video.elapsedSeconds ?? 0)) > Const.updateTimeMinimum else {
            return
        }
        Log.info("applyRemotePosition: \(seconds)")
        updateElapsedTime(seconds, videoId: video.youtubeId)
        if seek {
            backend.seek(to: seconds)
        }
    }

    @MainActor
    func publishPosition(_ seconds: Double? = nil, throttled: Bool = false) {
        guard let youtubeId = video?.youtubeId,
              let seconds = seconds ?? precisePosition?() ?? currentTime else { return }
        PlaybackPositionSync.shared.publish(youtubeId, seconds: seconds, throttled: throttled)
    }

    @MainActor
    func noteLocalInteraction() {
        guard let youtubeId = video?.youtubeId else { return }
        PlaybackPositionSync.shared.noteInteraction(youtubeId)
    }

    @MainActor
    func handleLocalSeek(_ target: Double) {
        if isPlaying {
            noteLocalInteraction()
        } else {
            publishPosition(target)
        }
    }
}
