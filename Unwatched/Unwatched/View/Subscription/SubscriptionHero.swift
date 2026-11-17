//
//  SubscriptionHero.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// The page's hero: artwork over a blurred copy of it, the title block and a row of setting chips.
/// Shared by the subscription page and the Search previews of channels and podcasts that aren't added.
struct SubscriptionHero<Header: View, Chips: View>: View {
    let artwork: SubscriptionArtwork
    var backgroundUrl: URL?
    var useThemeColor = false
    @Binding var showTitle: Bool
    @ViewBuilder var header: Header
    @ViewBuilder var chips: Chips

    var body: some View {
        VStack(spacing: 12) {
            artwork
                .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
                #if os(macOS)
                .padding(.top, 12)
            #endif

            header
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chips
                }
                .padding(.horizontal, 20)
            }
            .environment(\.settingControlStyle, .chip)
            .padding(.top, 4)
        }
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .modifier(ArtworkBackground(url: backgroundUrl, useThemeColor: useThemeColor))
        .onAppear {
            withAnimation(.default.speed(1.5)) { showTitle = false }
        }
        .onDisappear {
            withAnimation(.default.speed(1.5)) { showTitle = true }
        }
        .listRowSeparator(.hidden)
        .myListRowBackground()
    }
}

struct SubscriptionHeroTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 30, weight: .bold))
            .multilineTextAlignment(.center)
    }
}

struct SubscriptionHeroMeta: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    /// "@handle · Channel", "Author · Podcast"
    static func text(handle: String?, isPodcast: Bool, isPlaylist: Bool) -> String {
        let kind = if isPodcast {
            String(localized: "mediaTypePodcast")
        } else if isPlaylist {
            String(localized: "playlist")
        } else {
            String(localized: "channel")
        }
        return [handle, kind].compactMap { $0 }.joined(separator: " · ")
    }
}

struct SubscriptionArtwork: View {
    let thumbnailUrl: URL?
    var isPodcast = false
    var isWatchLater = false
    var size: CGFloat = 132

    var body: some View {
        Group {
            if isWatchLater {
                WatchLaterAvatar(size: size)
            } else if let url = thumbnailUrl {
                CachedImageView(imageUrl: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.insetBackgroundColor
                }
            } else {
                Color.insetBackgroundColor
            }
        }
        .frame(width: size, height: size)
        .channelImageClip(isPodcast: isPodcast, cornerFactor: ChannelImageShape.heroCornerFactor)
    }
}

extension SubscriptionArtwork {
    init(subscription: Subscription) {
        self.init(
            thumbnailUrl: subscription.thumbnailUrl,
            isPodcast: subscription.isPodcast,
            isWatchLater: subscription.isWatchLater
        )
    }
}

private struct ArtworkBackground: ViewModifier {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    var url: URL?
    var useThemeColor: Bool

    #if os(iOS)
    let bleed: CGFloat = 200
    #else
    let bleed: CGFloat = 0
    #endif

    #if os(macOS)
    let fadeStart: CGFloat = 0.1
    #else
    let fadeStart: CGFloat = 0.45
    #endif

    func body(content: Content) -> some View {
        content
            .padding(.top, bleed)
            .background {
                // aspect fill would oversize the clip
                Color.clear
                    .overlay { artwork }
                    .clipped()
                    .mask(LinearGradient(
                        stops: [.init(color: .black, location: fadeStart), .init(color: .clear, location: 1)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    #if os(macOS)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25))
                #endif
            }
            .listRowInsets(EdgeInsets(top: -bleed, leading: 0, bottom: 0, trailing: 0))
    }

    @ViewBuilder var artwork: some View {
        if useThemeColor {
            theme.color.opacity(0.35)
        } else {
            CachedImageView(imageUrl: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.clear
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(1.4)
            .blur(radius: 40)
            .opacity(0.75)
        }
    }
}
