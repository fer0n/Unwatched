//
//  OrientationManager.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import UnwatchedShared

@Observable class OrientationManager {
    @MainActor
    static let shared = OrientationManager()

    var hasLeftEmpty = false

    @MainActor
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangeOrientation),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        updateOrientation()
    }

    @MainActor
    @objc private func didChangeOrientation() {
        Log.info("OrientationManager: didChangeOrientation")
        updateOrientation()
    }

    @MainActor
    private func updateOrientation() {
        let orientation = UIDevice.current.orientation
        hasLeftEmpty = orientation == .landscapeRight
    }

    @MainActor
    static func changeOrientation(to orientation: UIInterfaceOrientationMask) {
        guard UIDevice.isIphone,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        Log.info("ChangeOrientation to \(orientation)")
        shared.hasLeftEmpty = orientation == .landscapeLeft
    }

    /// Whether rotation is currently restricted to portrait because a podcast is the current video.
    @MainActor
    private(set) static var podcastOrientationLocked = false

    /// Podcasts have no picture worth rotating for, and unlike video, an audio episode keeps playing in the
    /// background/pocket, where accidental accelerometer-driven rotation just jitters the sheet.
    @MainActor
    static func updatePodcastOrientationLock() {
        guard UIDevice.isIphone else { return }
        let locked = PlayerManager.shared.isAudioOnly
        guard locked != podcastOrientationLocked else { return }
        podcastOrientationLocked = locked

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        if locked {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }
}
#endif
