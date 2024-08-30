//
//  OrientationManager.swift
//  Unwatched
//

import SwiftUI

struct OrientationManager {
    @MainActor
    static func changeOrientation(to orientation: UIInterfaceOrientationMask) {
        guard UIDevice.isIphone,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
    }
}
