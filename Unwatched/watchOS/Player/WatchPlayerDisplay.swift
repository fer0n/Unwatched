//
//  WatchPlayerDisplay.swift
//  UnwatchedWatch
//

import Foundation
import UnwatchedShared

/// What the player page draws, whichever player it is pointed at: the watch's own or the phone's.
struct WatchPlayerDisplay {
    var isPlaying = false
    var isLoading = false
    var title: String?
    var chapterTitle: String?
    var artworkUrl: URL?
    var isSquare = false
    var fraction: Double = 0
    var remaining: Double?
    var hasChapters = false
    var hasNextChapter = false
    var errorMessage: String?
    /// Nothing is loaded yet, so the controls offer what playing would start.
    var isUpNext = false

    /// - Parameter date: the moment the phone's position is carried forward to.
    init(phone state: WatchRemoteState?, at date: Date) {
        guard let state else { return }
        isPlaying = state.isPlaying
        title = state.title
        chapterTitle = state.chapterTitle
        artworkUrl = state.thumbnailUrl
        isSquare = state.isAudioOnly
        fraction = Self.fraction(of: state.position(at: date), in: state.duration)
        remaining = state.remaining(at: date)
        hasChapters = state.hasChapters
        hasNextChapter = state.hasNextChapter
    }

    @MainActor
    init(local player: WatchAudioPlayer, upNext: Video?) {
        let video = player.video ?? upNext
        isUpNext = player.video == nil && upNext != nil
        isPlaying = player.isPlaying
        isLoading = player.isLoading
        errorMessage = player.errorMessage
        title = video?.title
        chapterTitle = player.currentChapterTitle
        artworkUrl = video?.displayThumbnailUrl
        isSquare = video?.isAudioOnly == true
        fraction = Self.fraction(
            of: isUpNext ? (video?.elapsedSeconds ?? 0) : player.currentTime,
            in: isUpNext ? video?.duration : player.duration
        )
        remaining = player.currentEndTime.map { max(0, $0 - player.currentTime) }
        hasChapters = player.video != nil && !player.chapters.isEmpty
        hasNextChapter = player.hasNextChapter
    }

    private static func fraction(of elapsed: Double, in duration: Double?) -> Double {
        guard let duration, duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }
}

/// The controls, as something both players can be asked for.
enum WatchPlayerAction {
    case togglePlay
    case seek(Double)
    case previousChapter
    case nextChapter

    var remoteCommand: WatchRemoteCommand {
        switch self {
        case .togglePlay: .togglePlay
        case .seek(let seconds): .seek(seconds)
        case .previousChapter: .previousChapter
        case .nextChapter: .nextChapter
        }
    }
}
