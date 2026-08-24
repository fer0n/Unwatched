//
//  PlayerBackend.swift
//  UnwatchedShared
//

import Foundation

/// A playback engine the player can drive directly, without routing commands through a view update.
@MainActor
public protocol PlayerBackend: AnyObject {
    func play()
    func pause()

    /// Halts playback whatever state the engine is in — used before a reload, where waiting for readiness would leave
    /// the old audio running.
    func stop()

    func seek(to time: Double)
    func setRate(_ rate: Double)
    func setPip(_ enabled: Bool)

    /// Loads the player's current video, if the engine isn't already on it.
    func cueVideo()

    /// - Parameter force: push even if the engine hasn't taken its initial set yet, for the point
    ///   where the engine reports itself ready.
    func setChapterMarkers(force: Bool)

    /// Playback moved into another chapter.
    func handleChapterChanged()

    /// Selects an audio track. Native player only: the embedded page picks its own.
    func setAudioLanguage(_ code: String)

    /// Caps the video variant, 0 for automatic. Native player only.
    func setVideoQuality(_ height: Int)

    /// Reconciles playback with the trim-silence setting.
    func applyTrimSilence()
}

public extension PlayerBackend {
    /// Only the embedded web player draws its own chapter markers.
    func setChapterMarkers(force: Bool) {}

    func handleChapterChanged() {}

    /// Only the native player selects tracks and variants; the embedded page has neither.
    func setAudioLanguage(_ code: String) {}
    func setVideoQuality(_ height: Int) {}
    func applyTrimSilence() {}
}
