//
//  fullscreenSafeArea.swift
//  Unwatched
//

import SwiftUI

/**
 Adjusts a fullscreen video in 18/9 to avoid cutting into the notch/dynamic island depending on the device
 */
struct FullscreenSafeArea: ViewModifier {
    let device = Device.modelName
    var enable = true

    func body(content: Content) -> some View {
        content
            // scale down the video to avoid cutting into the notch/dynamic island
            .padding(.horizontal, enable ? -offset : 0)
    }

    var offset: CGFloat {
        let device = Device.modelName

        switch device {
        case _ where device.contains("iPhone XR"):
            return 14.5
        case _ where device.contains("iPhone XS"): // & XS Max
            return 13.8
        case _ where device.contains("iPhone 11 Pro"): // & 11 Pro Max
            return 13.8
        case _ where device.contains("iPhone 11"):
            return 14.5

        case _ where device.contains("iPhone 12 mini"):
            return 16.8
        case _ where device.contains("iPhone 12"): // & 12 Pro & 12 Pro Max
            return 14.8

        case _ where device.contains("iPhone 13 mini"):
            return 13.8
        case _ where device.contains("iPhone 13"): // & 13 Pro & 13 Pro Max
            return 13.1

        case _ where device.contains("iPhone 14 Pro"): // & 14 Pro Max
            return 10.8
        case _ where device.contains("iPhone 14"): // & 14 Plus
            return 13.1

        case _ where device.contains("iPhone 15"):
            // & 15 Pro & 15 Pro Max & 15 Plus
            return 10.8

        case _ where device.contains("iPhone 16 Pro"): // & 16 Pro Max
            return 11.1
        case _ where device.contains("iPhone 16e"):
            return 13.1
        case _ where device.contains("iPhone 16"): // & 16 Plus
            return 10.8

        default:
            return 0
        }
    }
}

extension View {
    func fullscreenSafeArea(enable: Bool) -> some View {
        self.modifier(FullscreenSafeArea(enable: enable))
    }
}
