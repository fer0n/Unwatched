//
//  HTTPCookie.swift
//  UnwatchedShared
//

import Foundation

public extension HTTPCookie {
    var isYoutubeDomain: Bool { domain.contains("youtube.com") }
    var isYoutubeCdnDomain: Bool { domain.contains("googlevideo.com") }
    var isGoogleDomain: Bool { isYoutubeDomain || domain.contains("google.com") }
}
