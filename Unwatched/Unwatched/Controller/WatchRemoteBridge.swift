//
//  WatchRemoteBridge.swift
//  Unwatched
//

#if os(iOS)
import Foundation
import Observation
import UnwatchedShared

/// The watch's player, driving this one through the hooks `WatchQueueProvider` calls in on.
@MainActor
enum WatchRemoteBridge {
    private static var loadedChapterImage: (url: URL, data: Data)?

    static func setup() {
        guard WatchQueueProvider.setup() else { return }
        WatchQueueProvider.remoteState = { state() }
        WatchQueueProvider.remoteCommand = { apply($0) }
        observe()
        loadChapterImage()
    }

    private static func state() -> WatchRemoteState {
        let player = PlayerManager.shared
        let video = player.video
        let chapterImage = currentChapterImage()
        return WatchRemoteState(
            isPlaying: player.isPlaying,
            title: video?.title,
            channelTitle: video?.subscription?.title,
            thumbnailUrl: video?.displayThumbnailUrl,
            isAudioOnly: video?.isAudioOnly == true,
            duration: video?.duration,
            position: player.currentTime ?? video?.elapsedSeconds ?? 0,
            speed: player.playbackSpeed,
            hasCustomSpeed: video?.subscription?.customSpeedSetting != nil,
            canSetCustomSpeed: video?.subscription != nil,
            speedLockTagName: video.flatMap(Tag.speedLockTag(for:))?.name,
            hasTagSpeed: video.flatMap(Tag.playbackSpeedTag(for:)) != nil,
            hasPreviousChapter: player.previousChapter != nil,
            hasNextChapter: player.nextChapter != nil,
            chapterTitle: player.currentChapter?.titleText,
            chapterImageUrl: chapterImage.url,
            chapterImageData: chapterImage.data,
            chapterEndTime: player.currentEndTime,
            continuousPlay: UserDefaults.standard.bool(forKey: Const.continuousPlay),
            trimSilence: UserDefaults.standard.bool(forKey: Const.trimSilence),
            // Only a downloaded file can be trimmed: the pauses are found by decoding ahead.
            canTrimSilence: video.map { PodcastDownloadManager.shared.downloadedIds.contains($0.youtubeId) } ?? false,
            theme: UserDefaults.standard.integer(forKey: Const.themeColor),
            seekSeconds: video.flatMap(Tag.seekSecondsTag(for:))?.seekSeconds,
            chapters: video?.sortedChapterData.map(WatchRemoteChapter.init)
        )
    }

    private static func apply(_ command: WatchRemoteCommand) {
        let player = PlayerManager.shared
        switch command {
        case .togglePlay:
            player.handlePlayButton()
        case .play(let youtubeId):
            guard let video = VideoService.getVideo(for: youtubeId) else {
                Log.info("watch remote: no video for \(youtubeId)")
                return
            }
            player.playVideo(video)
        case .seek(let seconds):
            _ = seconds < 0
                ? player.seekBackward(-seconds)
                : player.seekForward(seconds)
        case .setSpeed(let speed):
            player.playbackSpeed = speed
        case .setCustomSpeed(let enabled):
            player.setCustomSpeedEnabled(enabled)
        case .setTagSpeed(let enabled):
            player.setTagSpeedEnabled(enabled)
        case .previousChapter:
            _ = player.goToPreviousChapter()
        case .nextChapter:
            _ = player.goToNextChapter()
        case .next:
            player.markVideoWatched(showMenu: false, source: .userInteraction)
        case .setContinuousPlay(let enabled):
            UserDefaults.standard.set(enabled, forKey: Const.continuousPlay)
        case .setTrimSilence(let enabled):
            guard !enabled || CloudKeyValueStore.hasPremium else {
                return
            }
            player.setTrimSilence(enabled)
        case .setChapterActive(let startTime, let isActive):
            setChapterActive(startTime: startTime, isActive: isActive)
        case .setChapter(let startTime):
            guard let chapter = player.video?.sortedChapterData.first(where: { $0.startTime == startTime }) else {
                return
            }
            player.setChapter(chapter)
        case .setProgress(let youtubeId, let seconds):
            // The phone's own player owns the position of what it is playing itself.
            guard player.video?.youtubeId != youtubeId,
                  let modelId = VideoService.getModelId(for: youtubeId) else { return }
            VideoService.forceUpdateVideoNow(modelId, elapsedSeconds: seconds)
            return
        case .reportSyncMode(let fullSync):
            // Mirrored into this phone's own UserDefaults purely so SetupView.sendSettings can
            // read it — the watch's actual setting lives only on the watch.
            UserDefaults.standard.set(fullSync, forKey: Const.watchFullSync)
            return
        }
        WatchQueueProvider.pushRemoteState()
    }

    /// What the chapter list's toggle does, see `ChapterList.toggleChapter`.
    private static func setChapterActive(startTime: Double, isActive: Bool) {
        let player = PlayerManager.shared
        guard let video = player.video,
              let chapter = video.sortedChapterData.first(where: { $0.startTime == startTime }),
              chapter.isActive != isActive,
              isActive || CloudKeyValueStore.hasPremium else { return }
        if chapter.isIntro {
            video.keepIntro = isActive
        } else if chapter.isOutro {
            video.keepOutro = isActive
        } else {
            ChapterService.setChapterActive(isActive, chapter, of: video)
            video.chaptersDidChange()
        }
        try? video.modelContext?.save()
        player.handleChapterChange()
        // the page seeks by the chapters it was handed, so the edit has to reach it too
        player.backend.setChapterMarkers(force: false)
    }

    /// Minus the position: it moves four times a second, and the watch carries it forward itself.
    private static func observe() {
        withObservationTracking {
            let player = PlayerManager.shared
            _ = player.isPlaying
            _ = player.video?.youtubeId
            _ = player.video?.title
            _ = player.currentChapter?.title
            _ = player.currentChapter?.imageUrl
            _ = player.video?.chapterRevision
        } onChange: {
            Task { @MainActor in
                WatchQueueProvider.pushRemoteState()
                loadChapterImage()
                observe()
            }
        }
    }

    /// A local image goes out only with its bytes: the watch wouldn't retry a URL it failed to load.
    private static func currentChapterImage() -> (url: URL?, data: Data?) {
        guard let url = PlayerManager.shared.currentChapter?.imageUrl else { return (nil, nil) }
        guard ChapterImageStore.isLocal(url) else { return (url, nil) }
        guard let loaded = loadedChapterImage, loaded.url == url else { return (nil, nil) }
        return (url, loaded.data)
    }

    private static func loadChapterImage() {
        guard let url = PlayerManager.shared.currentChapter?.imageUrl,
              ChapterImageStore.isLocal(url),
              loadedChapterImage?.url != url else { return }
        Task {
            guard let data = await ChapterImageStore.watchData(for: url) else { return }
            loadedChapterImage = (url, data)
            WatchQueueProvider.pushRemoteState()
        }
    }
}
#endif
