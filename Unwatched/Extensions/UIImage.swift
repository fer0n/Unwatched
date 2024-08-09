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

#Preview {
    let url = URL(string: "https://i2.ytimg.com/vi/9pVd8_bjl1o/hqdefault.jpg")!
    guard let data = try? Data(contentsOf: url),
          let myImage = UIImage(data: data) else {
        return ZStack { }
    }

    let croppedImage = myImage.croppedYtThumbnail()
    return Image(uiImage: croppedImage)
}
