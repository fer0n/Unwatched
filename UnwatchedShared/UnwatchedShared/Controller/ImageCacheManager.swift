//
//  ImageCacheManager.swift
//  Unwatched
//

import Foundation
import SwiftUI
import SwiftData
import OSLog

/// Holds images in memory until `persistCache()` is called.
///
/// This avoids performance issues when saving data.
@Observable public class ImageCacheManager {
    private var cache = [String: ImageCacheInfo]()
    
    public init() { }
    
    subscript(id: String?) -> ImageCacheInfo? {
        get {
            guard let id else { return nil }
            return cache[id]
        }
        set {
            guard let id else { return }
            if let value = newValue {
                cache[id] = value
            }
        }
    }

    public func persistCache() async {
        let cache = cache
        await ImageService.persistImages(
            cache: cache
        )
        clearCacheAll()
    }

    public func clearCacheAll() {
        cache = [:]
    }

    public func clearCache(_ imageUrl: String) {
        cache[imageUrl] = nil
    }
}

public struct ImageCacheInfo {
    public var url: URL
    public var data: Data
}
