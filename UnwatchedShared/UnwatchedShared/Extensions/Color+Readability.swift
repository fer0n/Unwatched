//
//  Color+Readability.swift
//  UnwatchedShared
//

import SwiftUI

public enum ColorUsage {
    case fill
    case foreground
}

public extension Color {
    var contrastingTextColor: Color {
        luminance > 0.62 ? .black : .white
    }

    var luminance: Double {
        #if canImport(UIKit)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #else
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let red = ns.redComponent, green = ns.greenComponent, blue = ns.blueComponent
        #endif
        return 0.299 * red + 0.587 * green + 0.114 * blue
    }

    var saturation: Double {
        hsb.saturation
    }

    func isReadable(in colorScheme: ColorScheme, as usage: ColorUsage = .fill) -> Bool {
        switch (usage, colorScheme) {
        case (.fill, .dark): luminance >= 0.3
        case (.fill, _): luminance <= 0.85
        case (.foreground, .dark): luminance >= 0.6
        case (.foreground, _): luminance <= 0.42
        }
    }

    func shiftedToBeReadable(in colorScheme: ColorScheme, as usage: ColorUsage = .fill) -> Color? {
        var (hue, saturation, brightness) = hsb
        let step = 0.05
        for _ in 0..<40 {
            if colorScheme == .dark {
                if brightness < 1 {
                    brightness = min(1, brightness + step)
                } else {
                    saturation = max(0, saturation - step)
                }
            } else {
                brightness = max(0, brightness - step)
            }
            let shifted = Color(hue: hue, saturation: saturation, brightness: brightness)
            if shifted.isReadable(in: colorScheme, as: usage) {
                return shifted
            }
        }
        return nil
    }

    private var hsb: (hue: Double, saturation: Double, brightness: Double) {
        #if canImport(UIKit)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue, saturation, brightness)
        #else
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return (color.hueComponent, color.saturationComponent, color.brightnessComponent)
        #endif
    }
}
