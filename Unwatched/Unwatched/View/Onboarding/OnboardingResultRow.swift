//
//  OnboardingResultRow.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct OnboardingResultRow: View {
    @Environment(\.displayScale) private var displayScale

    let title: String
    var subtitle: String?
    var thumbnailUrl: URL?
    var isPodcast = false
    var isWatchLater = false
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
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: typeIcon)
                            .font(.caption2)
                            .fontWeight(.black)
                            .foregroundStyle(.secondary)

                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary.opacity(0.5)))
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

    var typeIcon: String {
        isPodcast ? "antenna.radiowaves.left.and.right" : "play.rectangle.fill"
    }

    @ViewBuilder var avatar: some View {
        if isWatchLater {
            WatchLaterAvatar(size: Self.avatarSize)
        } else {
            imageAvatar
        }
    }

    var imageAvatar: some View {
        CachedImageView(imageUrl: thumbnailUrl, maxPixelSize: ceil(Self.avatarSize * displayScale)) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Color.insetBackgroundColor
                Text(title.prefix(1))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .channelImageClip(isPodcast: isPodcast)
    }
}

extension OnboardingResultRow {
    init(result: OnboardingSearchResult, isSelected: Bool, showsDivider: Bool = false, toggle: @escaping () -> Void) {
        self.init(
            title: result.title,
            subtitle: result.subtitle,
            thumbnailUrl: result.thumbnailUrl,
            isPodcast: result.isPodcast,
            isWatchLater: result.isWatchLater,
            isSelected: isSelected,
            showsDivider: showsDivider,
            toggle: toggle
        )
    }
}

#Preview {
    List {
        OnboardingResultRow(
            result: OnboardingSearchSuggestions.all[0],
            isSelected: true,
            toggle: { }
        )
        OnboardingResultRow(
            result: OnboardingSearchSuggestions.all[1],
            isSelected: false,
            toggle: { }
        )
    }
    .environment(ImageCacheManager())
    .modelContainer(DataProvider.previewContainer)
}
