//
//  OnboardingResultRow.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct OnboardingResultRow: View {
    @Environment(\.displayScale) private var displayScale

    let result: OnboardingSearchResult
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
                    Text(result.title)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: typeIcon)
                            .font(.caption2)
                            .fontWeight(.black)
                            .foregroundStyle(.secondary)

                        if let subtitle = result.subtitle {
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
        result.isPodcast ? "antenna.radiowaves.left.and.right" : "play.rectangle.fill"
    }

    var avatar: some View {
        CachedImageView(imageUrl: result.thumbnailUrl, maxPixelSize: ceil(Self.avatarSize * displayScale)) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Color.insetBackgroundColor
                Text(result.title.prefix(1))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .channelImageClip(isPodcast: result.isPodcast)
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
