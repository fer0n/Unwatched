//
//  CarPlayQueueList.swift
//  Unwatched
//

#if os(iOS)
import CarPlay
import CoreMedia
import SwiftData
import UnwatchedShared

@MainActor
final class CarPlayQueueList {
    private struct Shown: Equatable {
        let ids: [String]
        let startable: [Bool]
        let progress: [Int]
        let currentId: String?
        let isPlaying: Bool
        let videoEnded: Bool
        let seekSeconds: Int
    }

    enum Content: Equatable {
        case queue(QueueTagSelection)
        case subscription(PersistentIdentifier)
    }

    let content: Content
    let template: CPListTemplate
    private unowned let scene: CarPlaySceneDelegate
    private var shown: Shown?
    private var firstLoadTask: Task<Void, Never>?
    var onFirstRows: (() -> Void)?

    private static var itemLimit: Int { min(50, CPListTemplate.maximumItemCount) }
    private static let firstScreenCount = 8

    var selection: QueueTagSelection? {
        if case .queue(let selection) = content {
            return selection
        }
        return nil
    }

    init(_ content: Content, title: String, scene: CarPlaySceneDelegate) {
        self.content = content
        self.scene = scene
        template = CPListTemplate(title: title, sections: [])
        template.tabTitle = title
        if case .queue = content {
            template.emptyViewTitleVariants = [String(localized: "noQueueItems")]
            template.emptyViewSubtitleVariants = [String(localized: "noQueueItemsDescription")]
        } else {
            template.emptyViewTitleVariants = [String(localized: "noVideosYet")]
        }
    }

    func cancel() {
        firstLoadTask?.cancel()
        firstRowsShown()
    }

    func reload(_ tags: [Tag]) {
        let context = DataProvider.mainContext
        let videos = videos(context, tags)
        let player = PlayerManager.shared
        let shown = Shown(
            ids: videos.map(\.youtubeId),
            startable: videos.map(BackgroundPlaybackManager.shared.canStart),
            progress: videos.map { Int((Self.progress(of: $0) ?? 0) * 20) },
            currentId: player.video?.youtubeId,
            isPlaying: player.isPlaying,
            videoEnded: player.videoEnded,
            seekSeconds: Int(player.userSeekSeconds)
        )
        guard shown != self.shown else {
            return
        }
        let isFirstLoad = self.shown == nil
        self.shown = shown
        template.trailingNavigationBarButtons = selection == nil ? [] : playerButtons(first: videos.first)

        firstLoadTask?.cancel()
        let artwork = scene.artwork
        let missing = videos.prefix(Self.firstScreenCount)
            .compactMap(CarPlayArtwork.url)
            .filter { artwork.cached($0) == nil }
        guard isFirstLoad, !missing.isEmpty else {
            return showRows(videos)
        }
        firstLoadTask = Task { [weak self] in
            await artwork.preload(missing)
            guard let self, !Task.isCancelled else {
                return
            }
            self.showRows(videos.filter { !$0.isDeleted })
        }
    }

    private func videos(_ context: ModelContext, _ tags: [Tag]) -> [Video] {
        switch content {
        case .queue(let selection):
            return QueueFilter(selection, tags).videos(context, limit: Self.itemLimit)
        case .subscription(let id):
            let subscription: Subscription? = context.existingModel(for: id)
            let videos = (subscription?.videos ?? []).filter { !$0.isDeleted }
            return Array(videos.sorted { ($0.publishedDate ?? .distantPast) > ($1.publishedDate ?? .distantPast) }
                            .prefix(Self.itemLimit))
        }
    }

    private func showRows(_ videos: [Video]) {
        let currentId = PlayerManager.shared.video?.youtubeId
        let items = videos.map { listItem(for: $0, isCurrent: $0.youtubeId == currentId) }
        template.updateSections([CPListSection(items: items)])
        firstRowsShown()
    }

    private func firstRowsShown() {
        let onFirstRows = onFirstRows
        self.onFirstRows = nil
        onFirstRows?()
    }

    private func play(_ youtubeId: String, completion: @escaping () -> Void = {}) {
        scene.play(youtubeId, in: selection, completion: completion)
    }
}

// MARK: Rows

extension CarPlayQueueList {
    private func listItem(for video: Video, isCurrent: Bool) -> CPListItem {
        let url = CarPlayArtwork.url(for: video)
        let artwork = scene.artwork
        let item = CPListItem(
            text: video.title,
            detailText: video.channelName,
            image: url.flatMap(artwork.cached),
            accessoryImage: nil,
            accessoryType: .none
        )
        item.isPlaying = isCurrent && PlayerManager.shared.isPlaying
        if #available(iOS 26.4, *) {
            item.playbackConfiguration = playbackConfiguration(for: video, isCurrent: isCurrent)
        }
        if let progress = Self.progress(of: video) {
            item.playbackProgress = progress
        }
        item.isEnabled = BackgroundPlaybackManager.shared.canStart(video)
        let youtubeId = video.youtubeId
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                guard let self else {
                    return completion()
                }
                self.play(youtubeId, completion: completion)
            }
        }
        artwork.attach(url, to: item)
        return item
    }

    @available(iOS 26.4, *)
    private func playbackConfiguration(for video: Video, isCurrent: Bool) -> CPPlaybackConfiguration {
        let player = PlayerManager.shared
        let action: CPPlaybackConfiguration.Action = if isCurrent && player.isPlaying {
            .pause
        } else if isCurrent && player.videoEnded {
            .replay
        } else {
            .play
        }
        // a car that can't show video never delivers the tap
        let canShowVideo = scene.supportsVideoPlayback
        return CPPlaybackConfiguration(
            preferredPresentation: video.isPodcast || !canShowVideo ? .audio : .video,
            playbackAction: action,
            // with an elapsed time, the remaining time wraps next to its progress bar
            elapsedTime: .zero,
            duration: CMTime(seconds: video.duration ?? 0, preferredTimescale: 600)
        )
    }

    private static func progress(of video: Video) -> Double? {
        guard let elapsed = video.elapsedSeconds, let duration = video.duration, duration > 0 else {
            return nil
        }
        return min(1, elapsed / duration)
    }

    private func playerButtons(first: Video?) -> [CPBarButton] {
        let player = PlayerManager.shared
        guard let youtubeId = player.video?.youtubeId ?? first?.youtubeId else {
            return []
        }
        let playImage = UIImage(systemName: player.isPlaying ? "pause.fill" : "play.fill") ?? UIImage()
        let playPause = CPBarButton(image: playImage) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.play(youtubeId)
            }
        }
        guard player.video != nil else {
            playPause.isEnabled = first.map(BackgroundPlaybackManager.shared.canStart) == true
            return [playPause]
        }
        let seconds = Int(player.userSeekSeconds)
        let seekImage = UIImage(systemName: "goforward.\(seconds)") ?? UIImage(systemName: "goforward") ?? UIImage()
        let seek = CPBarButton(image: seekImage) { _ in
            MainActor.assumeIsolated {
                Log.info("carPlay: seek forward")
                _ = PlayerManager.shared.seekForward()
            }
        }
        return [playPause, seek]
    }
}
#endif
