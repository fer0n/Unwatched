//
//  WatchNotificationHandlerViewModifier.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared
import AVKit
import SwiftData

struct WatchNotificationHandlerViewModifier: ViewModifier {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .watchInUnwatched)) {
                handleWatchInUnwatched($0)
            }
            .onReceive(NotificationCenter.default.publisher(for: .queueInUnwatched)) {
                handleQueueInUnwatched($0)
            }
            .onReceive(NotificationCenter.default.publisher(for: .inboxInUnwatched)) {
                handleInboxInUnwatched($0)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openInUnwatched)) {
                handleOpenInUnwatched($0)
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickAction)) {
                if let action = $0.object as? QuickAction {
                    handle(action)
                }
            }
            .onAppear {
                if let action = QuickAction.pending {
                    QuickAction.pending = nil
                    handle(action)
                }
            }
            #if os(iOS)
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            ) { _ in
                Log.sync.warning("didReceiveMemoryWarningNotification")
                UserDataService.clearMemory()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            ) { _ in
                handleRouteChange()
            }
            .onAppear {
                handleRouteChange()
            }
        #endif
    }

    #if os(iOS)
    private func handleRouteChange() {
        guard UserDefaults.standard.bool(forKey: Const.autoAirplayHD) else {
            Log.sync.info("autoAirplayHD off")
            return
        }
        let currentRoute = getCurrentRoute()
        Log.sync.info("autoAirplayHD route: \(currentRoute.rawValue)")
        player.setAirplayHD(currentRoute == .airplay)
    }

    private func getCurrentRoute() -> AudioRoute {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        guard let portType = outputs.first?.portType.rawValue else {
            return .unknown
        }
        return AudioRoute(rawValue: portType) ?? .unknown
    }
    #endif

    func handle(_ action: QuickAction) {
        Signal.log("QuickAction", parameters: ["type": action.rawValue])
        switch action {
        case .playPause: handlePlayPauseQuickAction()
        case .paste: SearchVM.shared.openOrSearchClipboard(navManager)
        case .search: handleSearch()
        }
    }

    func handlePlayPauseQuickAction() {
        Log.sync.info("handlePlayPauseQuickAction")
        if player.isPlaying {
            player.pause()
            return
        }
        if player.video == nil {
            guard player.topVideoInQueue(modelContext) != nil else { return }
            player.loadTopmostVideoFromQueue(modelContext: modelContext, source: .playWhenReady)
        } else {
            player.handlePlayButton()
        }
        navManager.handlePlay()
        Signal.playbackStarted("quickAction")
    }

    func handleSearch() {
        Log.sync.info("handleSearch")
        navManager.focusSearch()
    }

    func handleWatchInUnwatched(_ notification: NotificationCenter.Publisher.Output) {
        Log.sync.info("handleWatchInUnwatched")
        if let userInfo = notification.userInfo, let youtubeUrl = userInfo["youtubeUrl"] as? URL {
            addAndPlay(youtubeUrl, source: "shortcut")
        }
    }

    func handleQueueInUnwatched(_ notification: NotificationCenter.Publisher.Output) {
        Log.sync.info("handleQueueInUnwatched")
        if let userInfo = notification.userInfo,
           let youtubeUrl = userInfo["youtubeUrl"] as? URL {
            let isNext = userInfo["next"] as? Bool ?? false
            addAndQueue(youtubeUrl, at: isNext ? 1 : -1)
        }
    }

    func handleInboxInUnwatched(_ notification: NotificationCenter.Publisher.Output) {
        Log.sync.info("handleInboxInUnwatched")
        if let userInfo = notification.userInfo, let youtubeUrl = userInfo["youtubeUrl"] as? URL {
            _ = VideoService.addForeignUrls([youtubeUrl], in: .inbox)
        }
    }

    func handleOpenInUnwatched(_ notification: NotificationCenter.Publisher.Output) {
        Log.sync.info("handleOpenInUnwatched")
        guard let url = notification.userInfo?["youtubeUrl"] as? URL else { return }
        navManager.openVideoDetail(for: url)
    }

    func addAndPlay(_ url: URL, source: String) {
        navManager.handlePlay()
        Signal.playbackStarted(source)
        Task {
            do {
                if let video = try await VideoService.importFirst(url, in: .queue, at: 0) {
                    player.playVideo(video)
                }
            } catch {
                Log.sync.error("addAndPlay: \(error)")
            }
        }
    }

    func addAndQueue(_ url: URL, at index: Int = 1) {
        let task = VideoService.addForeignUrls([url], in: .queue, at: index)
        player.loadTopmostVideoFromQueue(after: task, modelContext: modelContext, source: .nextUp)
    }
}

extension View {
    func watchNotificationHandler() -> some View {
        self.modifier(WatchNotificationHandlerViewModifier())
    }
}

enum AudioRoute: String {
    case airplay = "AirPlay"
    case bluetooth = "BluetoothA2DPOutput"
    case speaker = "Speaker"
    case unknown = "Unknown"
}
