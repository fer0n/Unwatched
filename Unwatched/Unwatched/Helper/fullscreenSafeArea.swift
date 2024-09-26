//
//  fullscreenSafeArea.swift
//  Unwatched
//

import SwiftUI

/**
 Adjusts a fullscreen video in 18/9 to avoid cutting into the notch/dynamic island depending on the device
 */
struct FullscreenSafeArea: ViewModifier {
    let device = UIDevice.modelName
    var enable = true

    func body(content: Content) -> some View {
        content
            // scale down the video to avoid cutting into the notch/dynamic island
            .padding([.top, .bottom], enable ? offset.edge : 0)
            .offset(x: enable ? offset.x : 0)
    }

    var offset: (edge: CGFloat, x: CGFloat) {
        switch device {
        case _ where device.contains("iPhone 16"),
             _ where device.contains("iPhone 15"),
             _ where device.contains("iPhone 14 Pro"):
            return (7.8, 0)
        case _ where device.contains("iPhone 14"),
             _ where device.contains("iPhone 13"),
             _ where device.contains("iPhone 12"),
             _ where device.contains("iPhone 11"),
             _ where device.contains("iPhone X"):
            return (2, 0)
        default:
            return (0, 0)
        }
    }
}

extension View {
    func fullscreenSafeArea(enable: Bool, onlyOffsetRight: Bool = false) -> some View {
        self.modifier(FullscreenSafeArea(enable: enable))
    }
}
