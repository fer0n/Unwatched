//
//  CarPlaySceneDelegate.swift
//  Unwatched
//

#if os(iOS)
import CarPlay
import CoreMedia
import SwiftData
import UnwatchedShared

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPSessionConfigurationDelegate {
    private struct Shown: Equatable {
        let ids: [String]
        let startable: [Bool]
        let progress: [Int]
        let currentId: String?
        let isPlaying: Bool
        let videoEnded: Bool
        let seekSeconds: Int
        let tagSymbol: String?
    }

    private var interfaceController: CPInterfaceController?
    private var sessionConfiguration: CPSessionConfiguration?
    private var nowPlaying: CarPlayNowPlaying?
    private var queueTemplate: CPListTemplate?
    private let artwork = CarPlayArtwork()
    private var saveObserver: NSObjectProtocol?
    private var reloadTask: Task<Void, Never>?
    private var firstLoadTask: Task<Void, Never>?
    private var connection = 0
    private var selection: QueueTagSelection = .all
    private var shown: Shown?

    private static var itemLimit: Int { min(50, CPListTemplate.maximumItemCount) }
    private static let firstScreenCount = 8

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        connection += 1
        self.interfaceController = interfaceController
        artwork.displayScale = interfaceController.carTraitCollection.displayScale
        let sessionConfiguration = CPSessionConfiguration(delegate: self)
        self.sessionConfiguration = sessionConfiguration
        if #available(iOS 26.4, *) {
            Log.info("carPlay: connected, video: \(sessionConfiguration.supportsVideoPlayback)")
        } else {
            Log.info("carPlay: connected")
        }
        selection = PlayerManager.shared.playbackTag
        let nowPlaying = CarPlayNowPlaying(interfaceController: interfaceController)
        nowPlaying.install()
        self.nowPlaying = nowPlaying

        let template = CPListTemplate(title: String(localized: "queue"), sections: [])
        template.emptyViewTitleVariants = [String(localized: "noQueueItems")]
        template.emptyViewSubtitleVariants = [String(localized: "noQueueItemsDescription")]
        queueTemplate = template
        interfaceController.setRootTemplate(template, animated: false, completion: nil)

        reloadQueue()
        observePlayer()
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleReload()
            }
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        Log.info("carPlay: disconnected")
        connection += 1
        if let saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
        }
        saveObserver = nil
        reloadTask?.cancel()
        firstLoadTask?.cancel()
        shown = nil
        queueTemplate = nil
        self.interfaceController = nil
        sessionConfiguration = nil
        nowPlaying?.uninstall()
        nowPlaying = nil
    }

    private func observePlayer() {
        let connection = connection
        withObservationTracking {
            let player = PlayerManager.shared
            _ = player.isPlaying
            _ = player.videoEnded
            _ = player.video?.youtubeId
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.connection == connection else {
                    return
                }
                self.scheduleReload()
                self.observePlayer()
            }
        }
    }

    // saves come in bursts
    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else {
                return
            }
            self?.reloadQueue()
        }
    }

    private func reloadQueue() {
        guard let queueTemplate else {
            return
        }
        let context = DataProvider.mainContext
        let tags = Self.tags(context)
        if selection.tagId != nil && selection.tag(in: tags) == nil {
            selection = .all
        }
        let videos = QueueFilter(selection, tags).videos(context, limit: Self.itemLimit)
        let player = PlayerManager.shared
        let shown = Shown(
            ids: videos.map(\.youtubeId),
            startable: videos.map(BackgroundPlaybackManager.shared.canStart),
            progress: videos.map { Int((Self.progress(of: $0) ?? 0) * 20) },
            currentId: player.video?.youtubeId,
            isPlaying: player.isPlaying,
            videoEnded: player.videoEnded,
            seekSeconds: Int(player.userSeekSeconds),
            tagSymbol: tags.isEmpty ? nil : tagSymbol(tags)
        )
        guard shown != self.shown else {
            return
        }
        let isFirstLoad = self.shown == nil
        self.shown = shown
        queueTemplate.leadingNavigationBarButtons = tags.isEmpty ? [] : [tagButton(tags)]
        queueTemplate.trailingNavigationBarButtons = playerButtons(first: videos.first)

        firstLoadTask?.cancel()
        let missing = videos.prefix(Self.firstScreenCount)
            .compactMap(CarPlayArtwork.url)
            .filter { artwork.cached($0) == nil }
        guard isFirstLoad, !missing.isEmpty else {
            return showRows(videos)
        }
        firstLoadTask = Task { [weak self] in
            await self?.artwork.preload(missing)
            guard let self, !Task.isCancelled else {
                return
            }
            self.showRows(videos.filter { !$0.isDeleted })
        }
    }

    private func showRows(_ videos: [Video]) {
        let currentId = PlayerManager.shared.video?.youtubeId
        let items = videos.map { listItem(for: $0, isCurrent: $0.youtubeId == currentId) }
        queueTemplate?.updateSections([CPListSection(items: items)])
    }

    // the row's spinner shows until start returns
    private func play(_ youtubeId: String, completion: @escaping () -> Void) {
        Log.info("carPlay: tapped \(youtubeId)")
        Task {
            defer { completion() }
            let player = PlayerManager.shared
            if player.video?.youtubeId == youtubeId && player.isPlaying {
                player.pause()
                return
            }
            guard let video = VideoService.getVideo(for: youtubeId, modelContext: DataProvider.mainContext) else {
                reloadQueue()
                return
            }
            do {
                try await BackgroundPlaybackManager.shared.start(video: video)
                player.playbackTag = selection
                Signal.playbackStarted("carPlay")
                if #unavailable(iOS 26.4) {
                    showNowPlaying()
                }
            } catch {
                Log.error("carPlay: playing \(youtubeId) failed — \(error.localizedDescription)")
                showError(error)
            }
        }
    }

    private func showNowPlaying() {
        guard let interfaceController,
              interfaceController.topTemplate !== CPNowPlayingTemplate.shared else {
            return
        }
        interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
    }

    private func showError(_ error: Error) {
        let message = (error as? BackgroundPlaybackError).map { String(localized: $0.localizedStringResource) }
            ?? error.localizedDescription
        let alert = CPAlertTemplate(
            titleVariants: [message],
            actions: [
                CPAlertAction(title: String(localized: "ok"), style: .cancel) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                    }
                }
            ]
        )
        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }
}

// MARK: Rows

extension CarPlaySceneDelegate {
    private func listItem(for video: Video, isCurrent: Bool) -> CPListItem {
        let url = CarPlayArtwork.url(for: video)
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
                self?.play(youtubeId, completion: completion)
            }
        }
        if let url, artwork.cached(url) == nil {
            Task { [artwork] in
                if let image = await artwork.load(url) {
                    item.setImage(image)
                }
            }
        }
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
        let canShowVideo = sessionConfiguration?.supportsVideoPlayback == true
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
}

// MARK: Bar buttons and tags

extension CarPlaySceneDelegate {
    private func playerButtons(first: Video?) -> [CPBarButton] {
        let player = PlayerManager.shared
        guard let youtubeId = player.video?.youtubeId ?? first?.youtubeId else {
            return []
        }
        let playImage = UIImage(systemName: player.isPlaying ? "pause.fill" : "play.fill") ?? UIImage()
        let playPause = CPBarButton(image: playImage) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.play(youtubeId) {}
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

    private static func tags(_ context: ModelContext) -> [Tag] {
        (try? context.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.order)]))) ?? []
    }

    private func tagSymbol(_ tags: [Tag]) -> String {
        selection.tag(in: tags)?.symbol ?? Const.queueTagSF
    }

    private func tagButton(_ tags: [Tag]) -> CPBarButton {
        CPBarButton(image: UIImage(systemName: tagSymbol(tags)) ?? UIImage()) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.showTagPicker()
            }
        }
    }

    private func showTagPicker() {
        let tags = Self.tags(DataProvider.mainContext)
        let options = [QueueTagSelection.all] + tags.map { .tag($0.persistentModelID) }
        let items = options.map { option in
            let tag = option.tag(in: tags)
            return CPListItem.option(
                tag?.name ?? String(localized: "allVideos"),
                symbol: tag.map { $0.symbol ?? $0.mode.defaultSymbol } ?? Const.queueTagSF,
                checked: option == selection
            ) { [weak self] in
                self?.select(option)
            }
        }
        let picker = CPListTemplate(title: String(localized: "tags"), sections: [CPListSection(items: items)])
        interfaceController?.pushTemplate(picker, animated: true, completion: nil)
    }

    private func select(_ option: QueueTagSelection) {
        Log.info("carPlay: showing tag \(option.tagId == nil ? "all" : "tag")")
        selection = option
        reloadQueue()
        interfaceController?.popTemplate(animated: true, completion: nil)
    }
}
#endif
