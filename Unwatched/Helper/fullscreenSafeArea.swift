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
    var onlyOffsetRight = false

    func body(content: Content) -> some View {
        if onlyOffsetRight {
            content
                .offset(x: enable ? offsetRight : 0)
        } else {
            content
                // scale down the video to avoid cutting into the notch/dynamic island
                .padding([.top, .bottom, .leading], enable ? offset.edge : 0)
                .offset(x: enable ? offset.x : 0)
        }
    }

    var offset: (edge: CGFloat, x: CGFloat) {
        print("device", device)
        switch device {
        case _ where device.contains("iPhone 15"),
             _ where device.contains("iPhone 14 Pro"):
            return (7.8, 0)
        case _ where device.contains("iPhone 14"),
             _ where device.contains("iPhone 13"),
             _ where device.contains("iPhone 12"),
             _ where device.contains("iPhone 11"),
             _ where device.contains("iPhone X"):
            return (2, 2)
        default:
            return (0, 0)
        }
    }

    var offsetRight: CGFloat {
        // use the safe area space on the right according to device
        switch device {
        case _ where device.contains("iPhone 15"),
             _ where device.contains("iPhone 14 Pro"):
            return 10
        case _ where device.contains("iPhone 14"),
             _ where device.contains("iPhone 13"),
             _ where device.contains("iPhone 12"),
             _ where device.contains("iPhone 11"),
             _ where device.contains("iPhone X"):
            return 2
        default:
            return 0
        }
    }
}

extension View {
    func fullscreenSafeArea(enable: Bool, onlyOffsetRight: Bool = false) -> some View {
        self.modifier(FullscreenSafeArea(enable: enable, onlyOffsetRight: onlyOffsetRight))
    }
}
