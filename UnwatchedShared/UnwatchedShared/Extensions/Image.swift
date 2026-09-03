//
//  UIImage.swift
//  UnwatchedShared
//

import SwiftUI
import ImageIO

public extension CGImage {
    func pixelColors(at points: [CGPoint]) -> [Color] {
        let width = self.width
        let height = self.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var pixelData = [UInt8](repeating: 0, count: Int(width * height * 4))

        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return Array(repeating: .clear, count: points.count)
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        var colors = [Color]()
        for point in points {
            let xVal = Int(point.x)
            let yVal = Int(point.y)
            let pixelIndex = ((width * yVal) + xVal) * bytesPerPixel

            let red = CGFloat(pixelData[pixelIndex]) / 255.0
            let green = CGFloat(pixelData[pixelIndex + 1]) / 255.0
            let blue = CGFloat(pixelData[pixelIndex + 2]) / 255.0
            // let alpha = CGFloat(pixelData[pixelIndex + 3]) / 255.0

            let color = Color(red: red, green: green, blue: blue)
            colors.append(color)
        }

        return colors
    }
}

/// Decodes straight to a bounded pixel size via ImageIO instead of materializing the source image at full resolution
/// first.
private func downsampledCGImage(from data: Data, maxPixelSize: CGFloat) -> CGImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }

    let downsampleOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ] as CFDictionary
    return CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions)
}

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
public typealias PlatformImage = UIImage

public extension UIImage {
    convenience init?(downsampling data: Data, maxPixelSize: CGFloat) {
        guard let cgImage = downsampledCGImage(from: data, maxPixelSize: maxPixelSize) else { return nil }
        self.init(cgImage: cgImage)
    }

    func pixelColors(at points: [CGPoint]) -> [Color] {
        guard let cgImage = self.cgImage else {
            return Array(repeating: .clear, count: points.count)
        }

        return cgImage.pixelColors(at: points)
    }

    func extractVibrantAccentColor() -> Color? {
        guard let cgImage = self.cgImage else { return nil }
        return cgImage.extractVibrantAccentColor()
    }

    func uniformEdgeColors() -> (edge: Color, center: Color)? {
        cgImage?.uniformEdgeColors()
    }

    /// Approximate decoded size in bytes, used as the `NSCache` cost in `DecodedImageCache`.
    var decodedByteCost: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }

    /// Decodes the image up front so the render pass doesn't have to. Call off the main thread.
    func readyForDisplay() -> UIImage {
        preparingForDisplay() ?? self
    }

    /// Scales an already-decoded image down, for when a smaller size of the same picture is wanted and re-reading
    /// the source would cost a full decode.
    func scaledDown(maxPixelSize: CGFloat) -> UIImage? {
        guard let cgImage else { return nil }
        let side = CGFloat(max(cgImage.width, cgImage.height))
        guard side > maxPixelSize else { return self }
        let scale = maxPixelSize / side
        let target = CGSize(width: CGFloat(cgImage.width) * scale, height: CGFloat(cgImage.height) * scale)
        return preparingThumbnail(of: target)
    }
}
#endif

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage

public extension NSImage {
    convenience init?(downsampling data: Data, maxPixelSize: CGFloat) {
        guard let cgImage = downsampledCGImage(from: data, maxPixelSize: maxPixelSize) else { return nil }
        self.init(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    func pixelColors(at points: [CGPoint]) -> [Color] {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return Array(repeating: .clear, count: points.count)
        }

        return cgImage.pixelColors(at: points)
    }

    func extractVibrantAccentColor() -> Color? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return cgImage.extractVibrantAccentColor()
    }

    func uniformEdgeColors() -> (edge: Color, center: Color)? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)?.uniformEdgeColors()
    }

    /// Approximate decoded size in bytes, used as the `NSCache` cost in `DecodedImageCache`.
    var decodedByteCost: Int {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }

    func readyForDisplay() -> NSImage { self }

    /// Scales an already-decoded image down, for when a smaller size of the same picture is wanted and re-reading
    /// the source would cost a full decode.
    func scaledDown(maxPixelSize: CGFloat) -> NSImage? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let side = CGFloat(max(cgImage.width, cgImage.height))
        guard side > maxPixelSize else { return self }
        let scale = maxPixelSize / side
        let width = Int((CGFloat(cgImage.width) * scale).rounded())
        let height = Int((CGFloat(cgImage.height) * scale).rounded())
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = context.makeImage() else { return nil }
        return NSImage(cgImage: scaled, size: NSSize(width: width, height: height))
    }
}

#endif
