//
//  CachedImage.swift
//  Unwatched
//

import Foundation
import SwiftData
import SwiftUI

@Model public final class CachedImage {
    @Attribute(.unique) public var imageUrl: URL?
    @Attribute(.externalStorage) public var imageData: Data?
    public var createdOn: Date?
    public var colorHex: String?

    public var color: Color? {
        get {
            guard let colorHex else { return nil }
            return Color(hex: colorHex)
        }
        set {
            if let newValue {
                colorHex = newValue.toHex()
            } else {
                colorHex = nil
            }
        }
    }

    public init(_ imageUrl: URL, imageData: Data, color: Color? = nil) {
        self.imageUrl = imageUrl
        self.imageData = imageData
        self.createdOn = .now
        self.color = color
    }
}
