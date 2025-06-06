//
//  UIImage.swift
//  UnwatchedShared
//


import SwiftUI


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

#if os(iOS) || os(tvOS)
import UIKit
public typealias PlatformImage = UIImage

public extension UIImage {
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

}
#endif

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage

public extension NSImage {
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
}

#endif
