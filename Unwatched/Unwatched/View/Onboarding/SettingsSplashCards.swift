//
//  SettingsSplashCards.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

enum SplashCardLayout {
    static let iconWidth: CGFloat = 32
    static let iconSpacing: CGFloat = 14
    static var textInset: CGFloat { iconWidth + iconSpacing }
}

struct SplashCardList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 12, content: content)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
                .padding(.vertical, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct SplashCard<Trailing: View, Footer: View>: View {
    let systemName: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    var premium = false
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: SplashCardLayout.iconSpacing) {
                Image(systemName: systemName)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: SplashCardLayout.iconWidth)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                        if premium {
                            PremiumIndicator()
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailing()
            }
            footer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.insetBackgroundColor)
        )
        .containsPremium(premium)
    }
}

extension SplashCard where Footer == EmptyView {
    init(
        systemName: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey?,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.init(systemName: systemName, title: title, subtitle: subtitle, trailing: trailing, footer: { EmptyView() })
    }
}

extension SplashCard where Trailing == EmptyView, Footer == EmptyView {
    init(systemName: String, title: LocalizedStringKey, subtitle: LocalizedStringKey?, premium: Bool = false) {
        self.init(
            systemName: systemName,
            title: title,
            subtitle: subtitle,
            premium: premium,
            trailing: { EmptyView() },
            footer: { EmptyView() }
        )
    }
}

struct SplashPickerRow: View {
    let title: LocalizedStringKey
    @Binding var selection: Int
    let options: [Int]
    let label: (Int) -> LocalizedStringKey

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}
