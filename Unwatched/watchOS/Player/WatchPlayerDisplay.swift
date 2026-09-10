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
    /// How far the seek buttons move in what is playing.
    var seek = WatchSeek.default

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
        seek = WatchSeek(tagSeconds: state.seekSeconds)
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
        // What is playing was resolved when it started; nothing is playing yet in the up-next
        // state, so that one is looked up here, where no timeline is running.
        seek = isUpNext
            ? WatchSeek(tagSeconds: video.flatMap(Tag.seekSecondsTag(for:))?.seekSeconds)
            : player.seekIntervals
    }

    private static func fraction(of elapsed: Double, in duration: Double?) -> Double {
        guard let duration, duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }
}

/// How far the seek buttons move, in either direction.
///
/// A tag's own duration is one number that applies both ways, as it does on the phone. Where no tag
/// decided, the watch keeps the asymmetric pair its controls have always used: a step back is for
/// catching what was missed, a step forward for skipping past something.
struct WatchSeek: Equatable {
    var back: Double
    var forward: Double

    static let `default` = WatchSeek(back: 15, forward: 30)

    init(back: Double, forward: Double) {
        self.back = back
        self.forward = forward
    }

    init(tagSeconds: Double?) {
        guard let tagSeconds, tagSeconds > 0 else {
            self = .default
            return
        }
        self.init(back: tagSeconds, forward: tagSeconds)
    }

    /// The numbered symbol where one exists for the duration, and the bare arrow otherwise: SF
    /// Symbols draws `gobackward.15` but nothing for, say, 23 seconds.
    static func symbol(forward: Bool, seconds: Double) -> String {
        let base = forward ? "goforward" : "gobackward"
        let rounded = Int(seconds.rounded())
        guard Double(rounded) == seconds, numberedSymbols.contains(rounded) else { return base }
        return "\(base).\(rounded)"
    }

    private static let numberedSymbols: Set<Int> = [5, 10, 15, 30, 45, 60, 75, 90]
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
