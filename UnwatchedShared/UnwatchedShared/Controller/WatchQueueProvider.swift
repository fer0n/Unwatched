//
//  WatchQueueProvider.swift
//  UnwatchedShared
//

#if os(iOS)
import AVFoundation
import Foundation
import SwiftData
import WatchConnectivity

actor WatchQueueSnapshotActor: SharedContextActor {
    func snapshot(limit: Int) throws -> WatchQueueSnapshot {
        var descriptor = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order)])
        descriptor.fetchLimit = limit
        let entries = try modelContext.fetch(descriptor)

        let items = entries.compactMap { entry -> WatchQueueSnapshot.Item? in
            guard let video = entry.video else { return nil }
            return WatchQueueSnapshot.Item(
                youtubeId: video.youtubeId,
                title: video.title,
                order: entry.order,
                thumbnailUrl: video.displayThumbnailUrl,
                duration: video.duration,
                elapsedSeconds: video.elapsedSeconds,
                channelTitle: video.subscription?.title,
                channelThumbnailUrl: video.subscription?.thumbnailUrl,
                mediaUrl: video.mediaUrl,
                isAudioOnly: video.isAudioOnly,
                customSpeedSetting: video.subscription?.customSpeedSetting
            )
        }
        let channelTitles = Set(items.compactMap(\.channelTitle))
        let youtubeIds = Set(items.map(\.youtubeId))
        let tags = try modelContext.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.order)]))
            .map { tag in
                WatchQueueSnapshot.TagItem(
                    name: tag.name,
                    order: tag.order,
                    mode: tag.mode.rawValue,
                    symbol: tag.symbol,
                    quickSwitch: tag.quickSwitch,
                    channelTitles: (tag.subscriptions ?? [])
                        .map(\.title)
                        .filter(channelTitles.contains),
                    youtubeIds: (tag.videos ?? [])
                        .map(\.youtubeId)
                        .filter(youtubeIds.contains),
                    seekSeconds: tag.seekSeconds,
                    continuousPlay: tag.continuousPlay,
                    playbackSpeed: tag.playbackSpeed
                )
            }

        return WatchQueueSnapshot(items: items, tags: tags)
    }

    func totals() throws -> WatchQueueSnapshot.Totals {
        WatchQueueSnapshot.Totals(
            videos: try modelContext.fetchCount(FetchDescriptor<Video>()),
            subscriptions: try modelContext.fetchCount(FetchDescriptor<Subscription>()),
            queue: try modelContext.fetchCount(FetchDescriptor<QueueEntry>()),
            tags: try modelContext.fetchCount(FetchDescriptor<Tag>()),
            chapters: try modelContext.fetchCount(FetchDescriptor<Chapter>())
        )
    }
}

public final class WatchQueueProvider: NSObject, WCSessionDelegate {
    public static let shared = WatchQueueProvider()

    /// Set by the app: `PlayerManager` lives in the app target, not here.
    @MainActor public static var remoteState: (() -> WatchRemoteState)?
    @MainActor public static var remoteCommand: ((WatchRemoteCommand) -> Void)?

    @MainActor private static var pushTask: Task<Void, Never>?

    /// Long enough for the player to have acted on a command before its state is read back.
    private static let settleDelay = Duration.milliseconds(200)
    /// Folds a flurry into one push: a track change moves several properties at once.
    private static let pushDelay = Duration.milliseconds(250)
    /// The volume moves in steps of about a sixteenth, faster than they are worth sending.
    private static let volumeInterval: TimeInterval = 0.08

    @discardableResult
    public static func setup() -> Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        session.delegate = shared
        session.activate()
        return true
    }

    /// Application context rather than a message: the system keeps only the latest, and delivers it
    /// whether or not the watch app is running. Only the guard runs on the main thread — handing
    /// the context to the daemon measured 0.3ms typically but 10-20ms now and then.
    @MainActor
    public static func pushRemoteState() {
        guard hasWatchApp else { return }
        pushTask?.cancel()
        pushTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: pushDelay)
            guard !Task.isCancelled, let state = await currentState() else { return }
            do {
                try WCSession.default.updateApplicationContext(
                    [WatchRemoteState.payloadKey: try state.encoded()]
                )
            } catch {
                Log.error("watch remote: could not push state: \(error)")
            }
        }
    }

    /// Checked before the state is built: with no watch app none of this is worth doing.
    @MainActor
    private static var hasWatchApp: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.activationState == .activated && session.isWatchAppInstalled
    }

    @MainActor
    private static func currentState() -> WatchRemoteState? {
        remoteState?()
    }

    @MainActor
    private static func remoteStateReply() -> [String: Any] {
        guard let message = try? remoteState?().message() else { return [:] }
        return message
    }

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if let error {
            Log.error("watch queue: session activation failed: \(error.localizedDescription)")
        }
        Log.info(
            "watch queue: session \(activationState.rawValue)"
                + " paired=\(session.isPaired) watchApp=\(session.isWatchAppInstalled)"
        )
        let isReachable = session.isReachable
        Task { @MainActor in
            Self.observeVolume(while: isReachable)
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { @MainActor in
            Self.observeVolume(while: isReachable)
        }
    }

    /// What the watch played on its own, queued by it while this phone was out of range.
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let command = WatchRemoteCommand.decoded(from: userInfo) else { return }
        Task { @MainActor in
            Self.remoteCommand?(command)
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if message[WatchRemoteState.requestKey] != nil {
            Task { @MainActor in
                replyHandler(Self.remoteStateReply())
            }
        } else if let command = WatchRemoteCommand.decoded(from: message) {
            Task { @MainActor in
                Self.remoteCommand?(command)
                try? await Task.sleep(for: Self.settleDelay)
                replyHandler(Self.remoteStateReply())
            }
        } else if message[WatchQueueSnapshot.Totals.requestKey] != nil {
            reply(to: replyHandler) { try await WatchQueueSnapshotActor().totals() }
        } else if message[WatchQueueSnapshot.requestKey] != nil {
            reply(to: replyHandler) {
                try await WatchQueueSnapshotActor().snapshot(limit: WatchQueueSnapshot.limit)
            }
        } else {
            replyHandler([:])
        }
    }

    // MARK: - Volume

    @MainActor private static var volumeObservation: NSKeyValueObservation?
    @MainActor private static var volumeTask: Task<Void, Never>?
    @MainActor private static var lastVolumeSend = Date.distantPast

    /// The crown turns this phone's volume through the system, which tells the watch nothing about
    /// where it landed. Only observed while the watch app is up.
    @MainActor
    private static func observeVolume(while isReachable: Bool) {
        guard isReachable else {
            volumeObservation = nil
            volumeTask?.cancel()
            return
        }
        guard volumeObservation == nil else { return }
        volumeObservation = AVAudioSession.sharedInstance().observe(
            \.outputVolume,
            options: [.new]
        ) { _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor in
                sendVolume(Double(value))
            }
        }
    }

    @MainActor
    private static func sendVolume(_ value: Double) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        volumeTask?.cancel()
        let wait = volumeInterval - Date.now.timeIntervalSince(lastVolumeSend)
        volumeTask = Task { @MainActor in
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
            }
            lastVolumeSend = .now
            session.sendMessage(WatchRemoteVolume.message(value), replyHandler: nil) { error in
                Log.error("watch remote: could not send the volume: \(error.localizedDescription)")
            }
        }
    }

    private func reply<Payload: WatchPayload>(
        to replyHandler: @escaping ([String: Any]) -> Void,
        with build: @escaping () async throws -> Payload
    ) {
        Task {
            do {
                replyHandler(try await build().message())
            } catch {
                Log.error("watch queue: could not answer request: \(error)")
                replyHandler([:])
            }
        }
    }
}
#endif
