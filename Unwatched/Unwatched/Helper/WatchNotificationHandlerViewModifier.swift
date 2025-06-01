//
//  WatchNotificationHandlerViewModifier.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared
import AVKit

struct WatchNotificationHandlerViewModifier: ViewModifier {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .watchInUnwatched)) {
                handleWatchInUnwatched($0)
            }
            .onReceive(NotificationCenter.default.publisher(for: .pasteAndWatch)) { _ in
                handlePasteAndPlay()
            }
            #if os(iOS)
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
            Log.info("autoAirplayHD off")
            return
        }
        let currentRoute = getCurrentRoute()
        Log.info("autoAirplayHD route: \(currentRoute.rawValue)")
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

    func handlePasteAndPlay() {
        Log.info("handlePasteAndPlay")
        guard let string = ClipboardService.get(), let url = URL(string: string) else {
            Log.warning("handlePasteAndPlay: no valid url pasted")
            return
        }
        addAndPlay(url)
    }

    func handleWatchInUnwatched(_ notification: NotificationCenter.Publisher.Output) {
        Log.info("handleWatchInUnwatched")
        if let userInfo = notification.userInfo, let youtubeUrl = userInfo["youtubeUrl"] as? URL {
            addAndPlay(youtubeUrl)
        }
    }

    func addAndPlay(_ url: URL) {
        let task = VideoService.addForeignUrls(
            [url],
            in: .queue,
            at: 0
        )
        player.loadTopmostVideoFromQueue(after: task, modelContext: modelContext, source: .userInteraction)
        navManager.handlePlay()
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
