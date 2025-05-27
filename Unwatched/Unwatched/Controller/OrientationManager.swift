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
}
#endif
