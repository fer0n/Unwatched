//
//  PageColorResolver.swift
//  UnwatchedShared
//

import SwiftUI

@MainActor
public struct PageColorResolver {
    let imageCacheManager: ImageCacheManager
    let colorScheme: ColorScheme

    public init(imageCacheManager: ImageCacheManager, colorScheme: ColorScheme) {
        self.imageCacheManager = imageCacheManager
        self.colorScheme = colorScheme
    }

    public func resolve(imageUrl: URL) async -> Color? {
        guard let info = await accentInfo(for: imageUrl), let primary = info.color else {
            return nil
        }
        if primary.isReadable(in: colorScheme) {
            return primary
        }
        if let stored = info.readableColors[colorScheme] {
            return stored
        }
        let readable = await readableAlternative(to: primary, imageUrl: imageUrl)
        guard !Task.isCancelled else { return nil }
        store(readable, for: imageUrl, fallback: info)
        return readable
    }

    public func iconColor(for pageColor: Color?) -> Color? {
        guard let pageColor, !pageColor.isReadable(in: colorScheme, as: .foreground) else {
            return pageColor
        }
        return pageColor.shiftedToBeReadable(in: colorScheme, as: .foreground) ?? pageColor
    }

    private func accentInfo(for imageUrl: URL) async -> ImageCacheInfo? {
        let cached: ImageCacheInfo? = imageCacheManager[imageUrl.absoluteString]
        if cached?.color != nil {
            return cached
        }
        let info = await ImageService.getAccentColor(from: imageUrl, imageCacheManager).value
        if let info {
            imageCacheManager[imageUrl.absoluteString] = info
        }
        return info
    }

    private func readableAlternative(to primary: Color, imageUrl: URL) async -> Color {
        if primary.saturation > 0.4, let shifted = primary.shiftedToBeReadable(in: colorScheme) {
            return shifted
        }
        let candidates = await ImageService.getAccentColorCandidates(from: imageUrl, imageCacheManager)
        if let candidate = candidates.first(where: { $0.saturation > 0.4 && $0.isReadable(in: colorScheme) }) {
            return candidate
        }
        return primary.shiftedToBeReadable(in: colorScheme) ?? (colorScheme == .dark ? .white : .black)
    }

    private func store(_ readable: Color, for imageUrl: URL, fallback: ImageCacheInfo) {
        let key = imageUrl.absoluteString
        var info: ImageCacheInfo = imageCacheManager[key] ?? fallback
        info.readableColors[colorScheme] = readable
        info.persistColor = true
        imageCacheManager[key] = info
    }
}
