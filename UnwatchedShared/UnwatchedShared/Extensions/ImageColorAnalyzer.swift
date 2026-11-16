//
//  ImageColorAnalyzer.swift
//  UnwatchedShared
//

import SwiftUI

public extension CGImage {
    func extractVibrantAccentColor() -> Color? {
        Log.info("extractVibrantAccentColor")
        let colorAnalyzer = ImageColorAnalyzer()
        let cgColor = colorAnalyzer.extractVibrantColor(from: self)
        return cgColor.map { Color($0) }
    }

    func extractVibrantAccentColors(limit: Int) -> [Color] {
        ImageColorAnalyzer().rankedVibrantColors(from: self).prefix(limit).map { Color($0) }
    }

    /// `extractVibrantAccentColor` first, then lower-ranked colors that look different from all before them.
    func extractDistinctAccentColors(limit: Int) -> [Color] {
        let ranked = ImageColorAnalyzer().rankedVibrantColorsWithShare(from: self)
        guard let first = ranked.first?.color else { return [] }
        var picked = [(color: first, lab: first.lab)]
        for (color, pixelShare) in ranked.dropFirst() where !color.isGray || (pixelShare >= 0.2 && color.isMidtone) {
            guard picked.count < limit else { break }
            let lab = color.lab
            if picked.allSatisfy({ $0.lab.distance(to: lab) >= Lab.distinctDistance }) {
                picked.append((color, lab))
            }
        }
        return picked.map { Color($0.color) }
    }
}

private class ImageColorAnalyzer {
    private let maxColors = 256
    private let colorTolerance: Float = 27.0 // HSB tolerance for grouping similar colors

    private let vibrancyWeight: Float = 1    // How much to prioritize saturation
    private let prominenceWeight: Float = 0.5  // How much to prioritize pixel count
    private let brightnessWeight: Float = 0.4  // How much to prioritize balanced brightness
    private let skinToneWeight: Float = 0.0001   // Penalty for likely skin tones

    // Ideal brightness range for scoring (middle range gets highest score)
    private let idealBrightnessRange: ClosedRange<Float> = 0.5...0.999

    func extractVibrantColor(from cgImage: CGImage) -> CGColor? {
        rankedVibrantColors(from: cgImage).first
    }

    func rankedVibrantColors(from cgImage: CGImage) -> [CGColor] {
        rankedVibrantColorsWithShare(from: cgImage).map(\.color)
    }

    func rankedVibrantColorsWithShare(from cgImage: CGImage) -> [(color: CGColor, pixelShare: Double)] {
        let colorCounts = groupSimilarColors(analyzeImageColors(cgImage))
        let totalPixelsSampled = colorCounts.values.reduce(0, +)
        let maxCount = colorCounts.values.max() ?? 1
        let scored: [(color: CGColor, count: Int, score: Float)] = colorCounts.map { color, count in
            let score = calculateColorScore(color: color, count: count, totalPixels: totalPixelsSampled, maxCount: maxCount)
            return (color, count, score)
        }
        let total = Double(max(totalPixelsSampled, 1))
        return scored
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                lhs.score != rhs.score ? lhs.score > rhs.score : lhs.color.precedes(rhs.color)
            }
            .map { ($0.color, Double($0.count) / total) }
    }

    private func analyzeImageColors(_ cgImage: CGImage) -> [CGColor: Int] {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return [:]
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return [:] }
        let buffer = data.assumingMemoryBound(to: UInt8.self)

        var colorCounts: [CGColor: Int] = [:]
        let step = max(1, totalBytes / (maxColors * bytesPerPixel)) // Sample pixels for performance

        for i in stride(from: 0, to: totalBytes, by: step * bytesPerPixel) {
            let red = CGFloat(buffer[i]) / 255.0
            let green = CGFloat(buffer[i + 1]) / 255.0
            let blue = CGFloat(buffer[i + 2]) / 255.0
            let alpha = CGFloat(buffer[i + 3]) / 255.0

            // Skip transparent pixels
            guard alpha > 0.5 else { continue }

            let color = CGColor(red: red, green: green, blue: blue, alpha: alpha)
            colorCounts[color, default: 0] += 1
        }

        return colorCounts
    }

    private func groupSimilarColors(_ colorCounts: [CGColor: Int]) -> [CGColor: Int] {
        var groupedColors: [CGColor: Int] = [:]
        var processedColors: Set<CGColor> = []

        let sortedCounts = colorCounts.sorted { lhs, rhs in
            lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key.precedes(rhs.key)
        }
        for (color, count) in sortedCounts {
            guard !processedColors.contains(color) else { continue }

            var totalCount = count
            var representativeColor = color
            processedColors.insert(color)

            // Find similar colors and group them
            for (otherColor, otherCount) in sortedCounts {
                guard otherColor != color,
                      !processedColors.contains(otherColor),
                      areColorsSimilar(color, otherColor) else { continue }

                totalCount += otherCount
                processedColors.insert(otherColor)

                // Use the color with higher saturation as representative
                if otherColor.saturation > representativeColor.saturation {
                    representativeColor = otherColor
                }
            }

            groupedColors[representativeColor] = totalCount
        }

        return groupedColors
    }

    private func areColorsSimilar(_ color1: CGColor, _ color2: CGColor) -> Bool {
        let hsb1 = color1.hsbComponents
        let hsb2 = color2.hsbComponents

        let hueDiff = abs(hsb1.hue - hsb2.hue) * 360
        let satDiff = abs(hsb1.saturation - hsb2.saturation) * 100
        let briDiff = abs(hsb1.brightness - hsb2.brightness) * 100

        return hueDiff < colorTolerance && satDiff < colorTolerance && briDiff < colorTolerance
    }

    private func calculateColorScore(color: CGColor, count: Int, totalPixels: Int, maxCount: Int) -> Float {
        let hsb = color.hsbComponents

        // Vibrancy score (0-1): Higher saturation is better
        let vibrancyScore = hsb.saturation

        // Prominence score (0-1): Normalize pixel count
        let prominenceScore = Float(count) / Float(maxCount)

        // Brightness score (0-1): Prefer colors in the ideal brightness range
        let brightnessScore: Float
        if idealBrightnessRange.contains(hsb.brightness) {
            brightnessScore = 1.0
        } else if hsb.brightness < idealBrightnessRange.lowerBound {
            // Too dark - score decreases as it gets darker
            brightnessScore = hsb.brightness / idealBrightnessRange.lowerBound
        } else {
            // Too bright - score decreases as it gets brighter
            brightnessScore = (1.0 - hsb.brightness) / (1.0 - idealBrightnessRange.upperBound)
        }

        // Apply penalties for extreme cases
        var penalty: Float = 1.0

        // Penalty for very low saturation (near grayscale)
        if hsb.saturation < 0.3 {
            if hsb.saturation < 0.2 {
                penalty *= 0.001
            } else {
                penalty *= 0.01
            }
        }

        // Penalty for very low prominence (less than x% of pixels)
        let prominence = Float(count) / Float(totalPixels)
        if prominence < 0.2 {
            if prominence < 0.1 {
                penalty *= 0.001
            } else {
                penalty *= 0.01
            }
        }

        // Penalty for extreme brightness (pure black or white)
        if hsb.brightness < 0.3 || hsb.brightness > 0.999 {
            if hsb.brightness < 0.01 || hsb.brightness > 0.9999 {
                penalty *= 0.0001
            } else if hsb.brightness < 0.1 {
                penalty *= 0.001
            } else {
                penalty *= 0.01
            }
        }

        // Penalty for likely skin tones
        if (hsb.hue > 0 && hsb.hue < 60) &&
           (hsb.saturation > 0.1 && hsb.saturation < 0.85) &&
           (hsb.brightness > 0.1 && hsb.brightness < 0.995) {
            penalty *= skinToneWeight
        }

        // Calculate weighted score
        let weightedScore = (vibrancyScore * vibrancyWeight) +
            (prominenceScore * prominenceWeight) +
            (brightnessScore * brightnessWeight)

        return weightedScore * penalty
    }
}

// MARK: - CGColor Extensions

private extension CGColor {
    var hsbComponents: (hue: Float, saturation: Float, brightness: Float) {
        guard let components = self.components, components.count >= 3 else {
            return (hue: 0, saturation: 0, brightness: 0)
        }

        let red = Float(components[0])
        let green = Float(components[1])
        let blue = Float(components[2])

        let maxComponent = max(red, green, blue)
        let minComponent = min(red, green, blue)
        let delta = maxComponent - minComponent

        // Calculate Hue
        var hue: Float = 0
        if delta != 0 {
            if maxComponent == red {
                hue = (green - blue) / delta
                hue = hue < 0 ? hue + 6 : hue
            } else if maxComponent == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue *= 60
        }

        // Calculate Saturation
        let saturation: Float = maxComponent == 0 ? 0 : delta / maxComponent

        // Calculate Brightness
        let brightness: Float = maxComponent

        return (hue: hue, saturation: saturation, brightness: brightness)
    }

    var saturation: Float {
        return hsbComponents.saturation
    }

    /// A fixed order for colors that tie, as Dictionary order changes from launch to launch.
    func precedes(_ other: CGColor) -> Bool {
        (components ?? []).lexicographicallyPrecedes(other.components ?? [])
    }

    var isGray: Bool {
        Double(saturation) < Color.graySaturation
    }

    var isMidtone: Bool {
        (0.25...0.9).contains(hsbComponents.brightness)
    }

    /// Assumes sRGB components, as `analyzeImageColors` draws in sRGB.
    var lab: Lab {
        guard let components, components.count >= 3 else { return Lab(l: 0, a: 0, b: 0) }
        func linear(_ value: CGFloat) -> Double {
            let value = Double(value)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let red = linear(components[0]), green = linear(components[1]), blue = linear(components[2])
        let x = (0.4124 * red + 0.3576 * green + 0.1805 * blue) / 0.95047
        let y = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        let z = (0.0193 * red + 0.1192 * green + 0.9505 * blue) / 1.08883
        func scaled(_ value: Double) -> Double {
            value > 216.0 / 24389 ? cbrt(value) : (24389.0 / 27 * value + 16) / 116
        }
        let fx = scaled(x), fy = scaled(y), fz = scaled(z)
        return Lab(l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }
}

struct Lab {
    static let distinctDistance = 30.0

    let l: Double, a: Double, b: Double

    func distance(to other: Lab) -> Double {
        let dl = l - other.l, da = a - other.a, db = b - other.b
        return (dl * dl + da * da + db * db).squareRoot()
    }
}

// shorts detection
#if os(iOS)
#Preview {
    @Previewable @State var imageColors: [Color] = [.gray, .gray, .gray, .gray]

    let urls = [
//        URL(string: "https://yt3.ggpht.com/lm_rPgM6BQFft9IdivtzaZMnZ3ab84yDrdjohb1CkO3tXXhGzPqs_N5sUSr32gFcIAflZCtCjw=s176-c-k-c0x00ffffff-no-rj-mo")!, // faevr
//        URL(string: "https://yt3.googleusercontent.com/ytc/AIdro_ndrznk18X0Sm4a8-tgnWB6yMUlSq_-hcCjN9SxEJ0S9PM=s160-c-k-c0x00ffffff-no-rj")!, // valve
//        URL(string: "https://yt3.ggpht.com/gvrEezxXgIqEv1k5zfp2fvMCOuL0uam774xGV0Sk9Vz2t_ytgqEO6GJE87dmt8q9MXkOaMe0Jw=s176-c-k-c0x00ffffff-no-rj-mo")!, // beardo benjo
//        URL(string: "https://yt3.googleusercontent.com/WgwnZy3sVim2cCBqCiRAXmQ8O_MFSc02Du52E74bFJGUaokjoXdBkAX7DL_Nv8TRQMYpp7jX=s160-c-k-c0x00ffffff-no-rj")!, // virtual bro
        URL(string: "https://yt3.googleusercontent.com/IBgiJOen7sXZxskS-BNsDVr_T5WLHSD4-jsvPRtmb_g1BkMSigXjv0uQyySxiF3Sq0BDriJfjcc=s900-c-k-c0x00ffffff-no-rj")!, // brandon
        URL(string: "https://yt3.googleusercontent.com/SgwRgpiAQqnfIhYI_FfWjlZHzqkVkhn9hylH1_rJl98h1Z_JNbtvhZO-fnEkhuG1Q_WeVBOHGg=s900-c-k-c0x00ffffff-no-rj")!, // jasmin
//        URL(string: "https://yt3.googleusercontent.com/XryXd0PS0zcIMjJE80UYOd0Azh5cdodscnvND66ViNFcsFoV29JBHYZfIwQqCzrm3A9QkZik=s900-c-k-c0x00ffffff-no-rj")!, // leeAnne
//        URL(string: "https://yt3.googleusercontent.com/ytc/AIdro_lO1dGNQA_KkLYNfUdZJYNbFA9FFTt0rsU1DC95T4A98Y0=s900-c-k-c0x00ffffff-no-rj")!, // habie
        URL(string: "https://yt3.googleusercontent.com/KxPzYd4N5kY8r1idQQKRZ_ulN6VYrkudnFJdXUINM3LcnpIcK4DJUrZFkTOnB11oh5Y0FWT25A=s900-c-k-c0x00ffffff-no-rj")!, // internet historian
        URL(string: "https://yt3.googleusercontent.com/qu4TmIaYUlS41-dJ9gZ7DUR3nilvmB5_11i6OKSdvNnBNiyOusZP1bMN6ICnuxtjFBb6ioKgRQ=s900-c-k-c0x00ffffff-no-rj")!, // Marque
        
    ]

    let images = urls.map { url in
        let data = try! Data(contentsOf: url)
        return UIImage(data: data)!
    }

    return VStack(spacing: 20) {
        ForEach(0..<images.count, id: \.self) { index in
            ZStack {
                imageColors[index]
                    .frame(width: 400, height: 150)
                Image(uiImage: images[index])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 100, maxHeight: 100)
                    .task {
                        if let col = await images[index].extractVibrantAccentColor() {
                            imageColors[index] = col
                        }
                    }
            }
            .cornerRadius(12)
        }
    }
    .padding()
}
#endif
