//
//  OnboardingChrome.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension View {
    /// Apply to the page's `ScrollView` itself, or the soft edge effect falls back to a default height
    func onboardingBottomBar<Accessory: View>(
        _ continueTitle: LocalizedStringKey,
        onContinue: @escaping () -> Void,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) -> some View {
        softSafeAreaBar(edge: .bottom) {
            VStack(spacing: 0) {
                accessory()
                OnboardingContinueButton(continueTitle, action: onContinue)
            }
            .padding(.bottom, 8)
            #if os(visionOS)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            #endif
        }
    }

    func onboardingSheetStyle() -> some View {
        modifier(OnboardingSheetStyle())
    }
}

private struct OnboardingSheetStyle: ViewModifier {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .setColorScheme()
            // visionOS puts the sheet on glass, an opaque plate on top of it would hide that
            .background { MyBackgroundColor(macOS: false) }
            .tint(theme.color)
            .interactiveDismissDisabled()
    }
}

struct OnboardingHeader: View {
    let title: LocalizedStringKey
    var description: LocalizedStringKey?

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            if let description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }
}

struct OnboardingContinueButton: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    let title: LocalizedStringKey
    let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.color)
        .foregroundStyle(theme.contrastColor)
        .controlSize(.large)
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.top, 8)
    }
}
