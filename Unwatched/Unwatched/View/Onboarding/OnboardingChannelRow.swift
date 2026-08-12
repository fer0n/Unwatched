//
//  OnboardingChannelRow.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct OnboardingChannelRow: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    let channel: YoutubeChannelSearchResult
    let isSelected: Bool
    var showsDivider = false
    let toggle: () -> Void

    private static let avatarSize: CGFloat = 42
    private static let avatarSpacing: CGFloat = 12

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: Self.avatarSpacing) {
                avatar

                VStack(alignment: .leading, spacing: 1) {
                    Text(channel.title)
                        .font(.headline)
                        .lineLimit(1)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? theme.color : Color.secondary.opacity(0.5))
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .overlay(alignment: .top) {
            if showsDivider {
                Divider()
                    .overlay(Color.automaticBlack.opacity(0.08))
                    .padding(.leading, Self.avatarSize + Self.avatarSpacing)
            }
        }
    }

    var subtitle: String? {
        [channel.subscriberCount, channel.userName.map { "@\($0)" }]
            .compactMap { $0 }
            .first
    }

    var avatar: some View {
        CachedImageView(imageUrl: channel.thumbnailUrl) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Color.insetBackgroundColor
                Text(channel.title.prefix(1))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .clipShape(Circle())
    }
}

#Preview {
    List {
        OnboardingChannelRow(
            channel: OnboardingChannelSuggestions.all[0],
            isSelected: true,
            toggle: { }
        )
        OnboardingChannelRow(
            channel: OnboardingChannelSuggestions.all[1],
            isSelected: false,
            toggle: { }
        )
    }
    .environment(ImageCacheManager())
    .modelContainer(DataProvider.previewContainer)
}
