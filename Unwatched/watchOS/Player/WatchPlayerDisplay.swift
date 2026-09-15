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
    var channelTitle: String?
    var artworkUrl: URL?
    var isSquare = false
    /// The two numbers that move on their own, as something the views drawing them can carry forward.
    var timeline: WatchTimeline = .fixed(fraction: 0, remaining: nil)
    var hasChapters = false
    var hasNextChapter = false
    var errorMessage: String?
    /// Nothing is loaded yet, so the controls offer what playing would start.
    var isUpNext = false
    /// How far the seek buttons move in what is playing.
    var seek = WatchSeek.default

    init(phone state: WatchRemoteState?) {
        guard let state else { return }
        isPlaying = state.isPlaying
        title = state.title
        chapterTitle = state.chapterTitle
        channelTitle = state.channelTitle
        artworkUrl = state.thumbnailUrl
        isSquare = state.isAudioOnly
        timeline = .phone(state)
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
        channelTitle = video?.subscription?.title
        artworkUrl = video?.displayThumbnailUrl
        isSquare = video?.isAudioOnly == true
        timeline = .fixed(
            fraction: WatchTimeline.fraction(
                of: isUpNext ? (video?.elapsedSeconds ?? 0) : player.currentTime,
                in: isUpNext ? video?.duration : player.duration
            ),
            remaining: player.currentEndTime.map { max(0, $0 - player.currentTime) }
        )
        hasChapters = player.video != nil && !player.chapters.isEmpty
        hasNextChapter = player.hasNextChapter
        // What is playing was resolved when it started; nothing is playing yet in the up-next
        // state, so that one is looked up here, where no timeline is running.
        seek = isUpNext
            ? WatchSeek(tagSeconds: video.flatMap(Tag.seekSecondsTag(for:))?.seekSeconds)
            : player.seekIntervals
    }

}

/// Where the ring's fill and the time left come from: the phone's reading, which carries forward on
/// its own, or a value the watch's own player already resolved.
enum WatchTimeline {
    case phone(WatchRemoteState)
    case fixed(fraction: Double, remaining: Double?)

    /// Whether anything moves between the states the phone sends.
    var isMoving: Bool {
        switch self {
        case .phone(let state): state.isPlaying
        case .fixed: false
        }
    }

    func fraction(at date: Date) -> Double {
        switch self {
        case .phone(let state): Self.fraction(of: state.position(at: date), in: state.duration)
        case .fixed(let fraction, _): fraction
        }
    }

    func remaining(at date: Date) -> Double? {
        switch self {
        case .phone(let state): state.remaining(at: date)
        case .fixed(_, let remaining): remaining
        }
    }

    static func fraction(of elapsed: Double, in duration: Double?) -> Double {
        guard let duration, duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }

    /// How long the fill takes to move one pixel along an arc that long; sooner than that it would
    /// redraw the same ring.
    func secondsPerPixel(ofArc pixels: Double) -> TimeInterval {
        guard case .phone(let state) = self,
              let duration = state.duration,
              duration > 0, state.speed > 0, pixels > 0 else { return 1 }
        return duration / pixels / state.speed
    }

    /// How long until the time left reads differently. It is drawn in a single unit rounded to the
    /// nearest, so it changes on the half unit below it — once a minute for most of an item.
    func secondsUntilRemainingChanges(at date: Date) -> TimeInterval {
        guard case .phone(let state) = self,
              let remaining = remaining(at: date),
              state.speed > 0 else { return 1 }
        let unit: Double = remaining >= 3600 ? 3600 : (remaining >= 60 ? 60 : 1)
        // The unit's own floor is a boundary too: below it the next unit down takes over.
        let target = max(unit == 1 ? 0 : unit, ((remaining / unit).rounded() - 0.5) * unit)
        return max(0, remaining - target) / state.speed
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
