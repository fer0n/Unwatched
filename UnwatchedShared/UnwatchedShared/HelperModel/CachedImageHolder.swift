//
//  ImageCached.swift
//  Unwatched
//

import Foundation
import SwiftData

public protocol CachedImageHolder {
    var thumbnailUrl: URL? { get set }
}
