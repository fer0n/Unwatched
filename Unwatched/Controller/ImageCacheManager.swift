//
//  ImageCacheManager.swift
//  Unwatched
//

import Foundation
import SwiftUI

@Observable class ImageCacheManager {
    private var cache: [URL: UIImage] = [:]
    subscript(url: URL?) -> UIImage? {
        get {
            guard let url else { return nil }
            return cache[url]
        }
        set {
            guard let url else { return }
            cache[url] = newValue
        }
    }
}
