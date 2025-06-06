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
    @MainActor
    public static let shared: ImageCacheManager = {
        ImageCacheManager()
    }()
    
    private var cache = [String: ImageCacheInfo]()
    public init() { }
    
    public subscript(id: String?) -> ImageCacheInfo? {
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

    @MainActor
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

public struct ImageCacheInfo: Sendable {
    public var url: URL
    public var data: Data
    public var color: Color?
    public var persistImage: Bool
    public var persistColor: Bool
    
    public init(
        url: URL,
        data: Data,
        color: Color? = nil,
        persistImage: Bool = true,
        persistColor: Bool = true
    ) {
        self.url = url
        self.data = data
        self.color = color
        self.persistImage = persistImage
        self.persistColor = persistColor
    }
}
