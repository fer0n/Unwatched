//
//  ImageCached.swift
//  Unwatched
//

import Foundation
import SwiftData

protocol CachedImageHolder {
    var thumbnailUrl: URL? { get set }
    var cachedImage: CachedImage? { get set }
    var persistentModelID: PersistentIdentifier { get }
}
