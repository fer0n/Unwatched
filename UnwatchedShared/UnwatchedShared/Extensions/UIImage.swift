//
//  UIImage.swift
//  UnwatchedShared
//

import UIKit

public extension UIImage {
    func pixelColors(at points: [CGPoint]) -> [UIColor] {
        guard let cgImage = self.cgImage else {
            return Array(repeating: .clear, count: points.count)
        }

        let width = cgImage.width
        let height = cgImage.height
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

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var colors = [UIColor]()
        for point in points {
            let xVal = Int(point.x)
            let yVal = Int(point.y)
            let pixelIndex = ((width * yVal) + xVal) * bytesPerPixel

            let red = CGFloat(pixelData[pixelIndex]) / 255.0
            let green = CGFloat(pixelData[pixelIndex + 1]) / 255.0
            let blue = CGFloat(pixelData[pixelIndex + 2]) / 255.0
            let alpha = CGFloat(pixelData[pixelIndex + 3]) / 255.0

            colors.append(UIColor(red: red, green: green, blue: blue, alpha: alpha))
        }

        return colors
    }
}
