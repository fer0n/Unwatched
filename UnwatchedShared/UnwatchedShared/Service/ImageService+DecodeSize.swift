//
//  ImageService+DecodeSize.swift
//  UnwatchedShared
//

import Foundation

extension ImageService {
    private static let decodeSizes: [CGFloat] = [128, 192, 256, 384, 512, 768, Const.maxDecodedImagePixelSize]

    public static func decodeSize(for requested: CGFloat) -> CGFloat {
        decodeSizes.first { $0 >= requested } ?? requested
    }
}
