//
//  UIImage.swift
//  Unwatched
//

import UIKit
import Foundation
import SwiftUI

public extension UIImage {
    func croppedImage(inRect rect: CGRect) -> UIImage {
        let rad: (Double) -> CGFloat = { deg in
            return CGFloat(deg / 180.0 * .pi)
        }
        var rectTransform: CGAffineTransform
        switch imageOrientation {
        case .left:
            let rotation = CGAffineTransform(rotationAngle: rad(90))
            rectTransform = rotation.translatedBy(x: 0, y: -size.height)
        case .right:
            let rotation = CGAffineTransform(rotationAngle: rad(-90))
            rectTransform = rotation.translatedBy(x: -size.width, y: 0)
        case .down:
            let rotation = CGAffineTransform(rotationAngle: rad(-180))
            rectTransform = rotation.translatedBy(x: -size.width, y: -size.height)
        default:
            rectTransform = .identity
        }
        rectTransform = rectTransform.scaledBy(x: scale, y: scale)
        let transformedRect = rect.applying(rectTransform)
        let imageRef = cgImage!.cropping(to: transformedRect)!
        let result = UIImage(cgImage: imageRef, scale: scale, orientation: imageOrientation)
        return result
    }

    func croppedYtThumbnail() -> UIImage {
        let width = self.size.width
        let height = self.size.height
        let newHeight = 9/16 * width
        return self.croppedImage(inRect: CGRect(
            x: 0,
            y: (height-newHeight) / 2,
            width: width,
            height: newHeight
        ))
    }
}

extension UIImage {
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

#Preview {
    let url = URL(string: "https://i2.ytimg.com/vi/9pVd8_bjl1o/hqdefault.jpg")!
    guard let data = try? Data(contentsOf: url),
          let myImage = UIImage(data: data) else {
        return ZStack { }
    }

    let croppedImage = myImage.croppedYtThumbnail()
    return Image(uiImage: croppedImage)
}
