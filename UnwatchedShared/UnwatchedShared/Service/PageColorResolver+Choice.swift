//
//  PageColorResolver+Choice.swift
//  UnwatchedShared
//

import SwiftUI

public extension PageColorResolver {
    private static var candidateCache = [URL: [Color]]()

    /// The image's main color first, then its other distinct colors.
    func candidates(imageUrl: URL) async -> [Color] {
        if let cached = Self.candidateCache[imageUrl] {
            return cached
        }
        let colors = await ImageService.getDistinctAccentColors(from: imageUrl, imageCacheManager, limit: 8)
        if !colors.isEmpty {
            Self.candidateCache[imageUrl] = colors
        }
        return colors
    }

    func color(for choice: PageColorChoice) -> Color? {
        switch choice {
        case .automatic: nil
        case .monochrome: colorScheme == .dark ? Color(.sRGB, white: 0xF5 / 255) : .black
        case .custom: choice.customColor.map(readable)
        }
    }
}
