//
//  BackgroundPlaybackManager.swift
//  Unwatched
//

import Foundation
import SwiftUI
import SwiftData
import UnwatchedShared

#if os(iOS)
import AVKit
import OSLog

/// Plays the queue with no view attached, so a shortcut can start playback while the app is in the
/// background. Switches to the native player: the web player is a `WKWebView` and needs a screen.
@MainActor
final class BackgroundPlaybackManager {
    static let shared = BackgroundPlaybackManager()

    private static let startTimeout: Double = 20

    private var player: PlayerManager { .shared }
    private var viewModel: AVPlayerViewModel { .shared }

    /// Returns once audio is running: the app is only kept alive past this by playback that started.
    /// - Parameters:
    ///   - tag: the slice to play, or `nil` to keep the latched one.
    ///   - video: what to play, or `nil` for the top of the queue. Loaded before anything else can
    ///     fail, so a caller that can fall back to the foreground (`PlayMediaIntentHandler`) finds
    ///     it staged and ready to play.
    func start(tag: QueueTagSelection? = nil, video: Video? = nil) async throws {
        if let video {
            // not `setNextVideo`: its fade would defer the swap past the `player.video` read below
            player.setVideoWithoutFade(video, .playWhenReady)
        }
        try enableNativePlayer()
        try activateAudioSession()
        if let tag, tag != player.playbackTag {
            player.playbackTag = tag
            player.loadTopmostVideoFromQueue(source: .playWhenReady, playIfCurrent: true)
        } else if player.video == nil {
            player.loadTopmostVideoFromQueue(source: .playWhenReady)
        }
        guard let videoId = player.video?.youtubeId else {
            throw BackgroundPlaybackError.noVideoInQueue
        }
        Log.info("backgroundPlayback: starting \(videoId)")
        viewModel.onVideoEnded = { [weak self] in self?.handleVideoEnded() }

        if viewModel.loadedVideoId == videoId {
            if player.videoEnded {
                player.restartVideo()
            } else {
                player.play()
            }
        } else {
            // started by `handleReadyToPlay` once the stream is up
            player.videoSource = .playWhenReady
            viewModel.loadVideoIfNeeded()
        }

        let started = await Poll.until(timeout: Self.startTimeout) { [weak self] in
            guard let self else {
                return .abort
            }
            if viewModel.avPlayer.timeControlStatus == .playing {
                return .done
            }
            return viewModel.loadError != nil ? .abort : .retry
        }
        guard started else {
            Log.warning("backgroundPlayback: \(videoId) didn't start")
            throw BackgroundPlaybackError.couldNotStart
        }
    }

    /// Up front, so being barred from playing in the background fails here rather than as a
    /// 20 second wait for a player that was never allowed to start.
    private func activateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
        } catch {
            Log.error("backgroundPlayback: audio session unavailable — \(error.localizedDescription)")
            throw BackgroundPlaybackError.couldNotStart
        }
    }

    private func enableNativePlayer() throws {
        // a podcast episode plays natively whatever the setting says
        guard PlayerTypeSetting.stored != .native, player.video?.isPodcast != true else {
            return
        }
        guard PlayerManager.nativeFallbackEnabled else {
            throw BackgroundPlaybackError.nativePlayerRequired
        }
        Log.info("backgroundPlayback: switching to the native player")
        UserDefaults.standard.set(PlayerTypeSetting.stored.rawValue, forKey: Const.previousPlayerType)
        UserDefaults.standard.set(PlayerTypeSetting.native.rawValue, forKey: Const.playerType)
        player.nativeFallbackActive = true
        PlayerSwitchManager.shared.handleSettingChanged()
    }

    /// `PlayerView.handleVideoEnded`, minus the review prompt.
    private func handleVideoEnded() {
        if player.isRepeating {
            player.seek(to: 0)
            return
        }
        let continuousPlay = UserDefaults.standard.bool(forKey: Const.continuousPlay)
        Log.info("backgroundPlayback: videoEnded, continuousPlay: \(continuousPlay)")
        guard continuousPlay else {
            if Const.markWatchedOnEnded.bool ?? true {
                player.markVideoWatched(showMenu: false)
            } else {
                player.pause()
                player.setVideoEnded(true)
            }
            return
        }
        let modelContext = DataProvider.mainContext
        if let video = player.video {
            VideoService.setVideoWatched(video, modelContext: modelContext)
            // workaround: sync clear is sometimes unreliable (e.g. screen locked);
            // async version ensures the queue entry is actually removed
            _ = VideoService.clearFromEverywhereAsync(video.youtubeId)

            TinyUndoManager.shared.registerAction(
                .moveToQueue([video.persistentModelID], position: 0)
            )
        }
        player.autoSetNextVideo(.continuousPlay, modelContext)
    }
}
#endif

enum BackgroundPlaybackError: Error, CustomLocalizedStringResourceConvertible {
    case nativePlayerRequired
    case noVideoInQueue
    case unsupportedPlatform
    case couldNotStart
    case tagNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .nativePlayerRequired:
            return "nativePlayerRequiredError"
        case .noVideoInQueue:
            return "noVideoInQueueError"
        case .unsupportedPlatform:
            return "backgroundPlaybackUnsupportedError"
        case .couldNotStart:
            return "couldNotStartPlaybackError"
        case .tagNotFound:
            return "tagNotFoundError"
        }
    }
}
