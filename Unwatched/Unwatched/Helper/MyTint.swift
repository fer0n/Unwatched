//
//  MyTint.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MyTint: ViewModifier {
    @AppStorage(Const.themeColor) var theme: ThemeColor = .defaultTheme
    @Environment(\.pageThemeColor) var pageThemeColor

    func body(content: Content) -> some View {
        content
            .tint(pageThemeColor ?? theme.color)
    }
}

/// Colors a page with its channel: the tint, progress bars, status badges, chips and swipe actions.
private struct ChannelPageColor: ViewModifier {
    @Environment(ImageCacheManager.self) var imageCacheManager
    @Environment(\.colorScheme) var colorScheme
    @State var pageColor: Color?

    /// nil: no channel color, e.g. on Watch Later
    let imageUrl: URL?

    func body(content: Content) -> some View {
        content
            .tint(pageColor)
            .environment(\.pageThemeColor, pageColor)
            .environment(\.swipeActionColor, pageColor?.darkenedForSwipeActions)
            .environment(\.pageForegroundColor, resolver.iconColor(for: pageColor))
            .task(id: PageColorKey(imageUrl: imageUrl, colorScheme: colorScheme)) {
                await resolvePageColor()
            }
            #if os(visionOS)
            .tint(nil)
        #endif
    }

    private var resolver: PageColorResolver {
        PageColorResolver(imageCacheManager: imageCacheManager, colorScheme: colorScheme)
    }

    private func resolvePageColor() async {
        guard let imageUrl else {
            pageColor = nil
            return
        }
        // no flash of the old or theme color when it's already known
        pageColor = resolver.cachedColor(imageUrl: imageUrl)
        let color = await resolver.resolve(imageUrl: imageUrl)
        guard !Task.isCancelled else { return }
        pageColor = color
    }
}

private struct PageColorKey: Equatable {
    let imageUrl: URL?
    let colorScheme: ColorScheme
}

extension Video {
    /// The channel avatar or podcast cover, else the video's own thumbnail.
    var channelColorImageUrl: URL? {
        subscription?.thumbnailUrl ?? thumbnailUrl
    }
}

extension View {
    func channelPageColor(imageUrl: URL?) -> some View {
        modifier(ChannelPageColor(imageUrl: imageUrl))
    }

    func myTint(neutral: Bool = false) -> some View {
        self.apply {
            if neutral && Device.isVision {
                $0.tint(nil)
            } else {
                $0.modifier(MyTint())
            }
        }
    }

    func visionForegroundColor() -> some View {
        self
            #if os(visionOS)
            .tint(.primary)
            .foregroundStyle(.primary)
        #endif
    }
}
