//
//  UniformEdgeColor.swift
//  UnwatchedShared
//

import SwiftUI

public extension CGImage {
    /// The two ends of the gradient the artwork backdrop draws, when the image's border is close enough to one
    /// colour. Both are nudged off the sampled colour, so the gradient still reads as a shift across the strips
    /// left and right of the art — its midpoint sits hidden behind the art itself.
    func uniformEdgeColors(
        tolerance: CGFloat = 0.055,
        minMatchRatio: CGFloat = 0.75,
        brightnessDelta: CGFloat = 0.14,
        edgeBrightnessFraction: CGFloat = 0.3
    ) -> (edge: Color, center: Color)? {
        let size = 12
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 0, count: size * size * bytesPerPixel)
        guard let context = CGContext(
            data: &pixels,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .medium
        context.draw(self, in: CGRect(x: 0, y: 0, width: size, height: size))

        var samples = [RGB]()
        var borderPixels = 0
        for x in 0..<size {
            for y in 0..<size where x == 0 || y == 0 || x == size - 1 || y == size - 1 {
                borderPixels += 1
                let index = ((y * size) + x) * bytesPerPixel
                // a transparent border says nothing about what's behind the art
                guard pixels[index + 3] > 200 else { continue }
                samples.append(RGB(
                    red: CGFloat(pixels[index]) / 255,
                    green: CGFloat(pixels[index + 1]) / 255,
                    blue: CGFloat(pixels[index + 2]) / 255
                ))
            }
        }
        guard !samples.isEmpty else { return nil }

        let mean = RGB.mean(of: samples)
        let inliers = samples.filter { $0.maxDeviation(from: mean) <= tolerance }
        guard CGFloat(inliers.count) / CGFloat(borderPixels) >= minMatchRatio else { return nil }

        let color = RGB.mean(of: inliers)
        return (
            edge: color.nudged(by: brightnessDelta * edgeBrightnessFraction),
            center: color.nudged(by: brightnessDelta)
        )
    }
}

/// A plain sRGB sample, for averaging pixels before they become a `Color`.
struct RGB {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    static func mean(of samples: [RGB]) -> RGB {
        let count = CGFloat(samples.count)
        return RGB(
            red: samples.reduce(0) { $0 + $1.red } / count,
            green: samples.reduce(0) { $0 + $1.green } / count,
            blue: samples.reduce(0) { $0 + $1.blue } / count
        )
    }

    func maxDeviation(from other: RGB) -> CGFloat {
        max(abs(red - other.red), abs(green - other.green), abs(blue - other.blue))
    }

    /// Darker for contrast against the art it frames, or brighter when it's already too dark to darken.
    func nudged(by delta: CGFloat) -> Color {
        let brightness = max(red, green, blue)
        let target = brightness >= delta ? brightness - delta : min(brightness + delta, 1)
        guard brightness > 0 else { return Color(white: target) }
        // scaling every component keeps hue and saturation, so only the brightness moves
        let scale = target / brightness
        return Color(red: red * scale, green: green * scale, blue: blue * scale)
    }
}
