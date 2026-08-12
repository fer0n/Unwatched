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
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.insetBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.color, lineWidth: isSelected ? 2 : 0)
            )
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
