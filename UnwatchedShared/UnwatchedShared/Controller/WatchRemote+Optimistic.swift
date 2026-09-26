//
//  WatchRemote+Optimistic.swift
//  UnwatchedShared
//

import Foundation

public extension WatchRemoteState {
    /// The state a command leaves the phone in, or `nil` where only the phone can say.
    func applying(_ command: WatchRemoteCommand) -> WatchRemoteState? {
        guard !isEmpty else { return nil }
        var state = self
        state.position = position(at: .now)
        state.positionDate = .now

        switch command {
        case .togglePlay:
            state.isPlaying.toggle()
        case .seek(let seconds):
            state.position = max(0, min(duration ?? .greatestFiniteMagnitude, state.position + seconds))
        case .setSpeed(let speed):
            state.speed = speed
        case .setCustomSpeed(let enabled):
            state.hasCustomSpeed = enabled
        case .setTagSpeed(let enabled):
            state.hasTagSpeed = enabled
        case .setContinuousPlay(let enabled):
            state.continuousPlay = enabled
        case .setTrimSilence(let enabled):
            state.trimSilence = enabled
        case .setChapterActive(let startTime, let isActive):
            guard let index = state.chapters?.firstIndex(where: { $0.startTime == startTime }) else {
                return nil
            }
            state.chapters?[index].isActive = isActive
        case .play, .previousChapter, .nextChapter, .next, .setProgress, .reportSyncMode:
            return nil
        }
        return state
    }

    /// An item about to start on the phone, as far as the watch's own copy of it decides.
    static func starting(_ video: Video, from current: WatchRemoteState?) -> WatchRemoteState {
        WatchRemoteState(
            isPlaying: true,
            title: video.title,
            channelTitle: video.subscription?.title,
            thumbnailUrl: video.displayThumbnailUrl,
            isAudioOnly: video.isAudioOnly == true,
            duration: video.duration,
            position: video.elapsedSeconds ?? 0,
            positionDate: .now,
            speed: current?.speed ?? 1,
            hasCustomSpeed: video.subscription?.customSpeedSetting != nil,
            canSetCustomSpeed: video.subscription != nil,
            speedLockTagName: Tag.speedLockTag(for: video)?.name,
            hasTagSpeed: Tag.playbackSpeedTag(for: video) != nil,
            continuousPlay: current?.continuousPlay ?? false,
            trimSilence: current?.trimSilence ?? false,
            theme: current?.theme,
            seekSeconds: Tag.seekSecondsTag(for: video)?.seekSeconds
        )
    }
}
