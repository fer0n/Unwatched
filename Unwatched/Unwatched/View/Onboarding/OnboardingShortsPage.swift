//
//  OnboardingShortsPage.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct OnboardingShortsPage: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @Binding var hideShorts: Bool

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            choice(
                title: "onboardingShortsNo",
                subtitle: "onboardingShortsNoDescription",
                systemName: "eye.slash.fill",
                isSelected: hideShorts
            ) {
                hideShorts = true
            }

            choice(
                title: "onboardingShortsYes",
                subtitle: "onboardingShortsYesDescription",
                systemName: "eye.fill",
                isSelected: !hideShorts
            ) {
                hideShorts = false
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .animation(.easeInOut(duration: 0.15), value: hideShorts)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hideShorts)
    }

    private static let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    func choice(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        systemName: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemName)
                    .font(.title2)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            // an opaque fill on the sheet's glass reads as a plate stuck on top of it
            #if os(visionOS)
            .glassBackgroundEffect(in: Self.shape)
            #else
            .background(Self.shape.fill(Color.insetBackgroundColor))
            #endif
            .overlay(Self.shape.strokeBorder(theme.color, lineWidth: isSelected ? 2 : 0))
            .opacity(isSelected ? 1 : 0.45)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    @Previewable @State var hideShorts = true
    OnboardingShortsPage(hideShorts: $hideShorts)
}
