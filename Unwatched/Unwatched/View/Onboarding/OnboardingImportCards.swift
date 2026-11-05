//
//  OnboardingImportCards.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct OnboardingImportCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let iconColor: Color
    let action: () -> Void

    private static let iconSize: CGFloat = 42

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: Self.iconSize, height: Self.iconSize)
                    .background(iconColor.gradient, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            #if os(visionOS)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 22))
            #else
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22))
            #endif
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingImportCards: View {
    let onImportFromYoutube: () -> Void
    let onImportPodcasts: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            OnboardingImportCard(
                title: "onboardingImportYoutube",
                subtitle: "onboardingImportYoutubeSubtitle",
                systemImage: "play.rectangle.fill",
                iconColor: .red,
                action: onImportFromYoutube
            )
            OnboardingImportCard(
                title: "onboardingImportPodcasts",
                subtitle: "onboardingImportPodcastsSubtitle",
                systemImage: "antenna.radiowaves.left.and.right",
                iconColor: .purple,
                action: onImportPodcasts
            )
        }
        .padding(.bottom, 16)
    }
}
