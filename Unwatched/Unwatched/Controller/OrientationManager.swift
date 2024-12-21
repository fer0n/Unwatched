//
//  OrientationManager.swift
//  Unwatched
//

import SwiftUI

@Observable class OrientationManager {
    var isLandscapeLeft: Bool = false
    var isLandscapeRight: Bool = false

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangeOrientation),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        updateOrientation()
    }

    @objc private func didChangeOrientation() {
        updateOrientation()
    }

    private func updateOrientation() {
        let orientation = UIDevice.current.orientation
        isLandscapeLeft = orientation == .landscapeLeft
        isLandscapeRight = orientation == .landscapeRight
    }

    @MainActor
    static func changeOrientation(to orientation: UIInterfaceOrientationMask) {
        guard UIDevice.isIphone,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
    }
}
