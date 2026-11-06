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
        prominent: Bool = true,
        onContinue: @escaping () -> Void,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) -> some View {
        softSafeAreaBar(edge: .bottom) {
            VStack(spacing: 0) {
                accessory()
                OnboardingContinueButton(continueTitle, prominent: prominent, action: onContinue)
            }
            .padding(.bottom, 8)
            #if os(visionOS)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            #endif
        }
    }

    func onboardingSheetStyle(dismissable: Bool = false) -> some View {
        modifier(OnboardingSheetStyle(dismissable: dismissable))
    }
}

private struct OnboardingSheetStyle: ViewModifier {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    let dismissable: Bool

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .setColorScheme()
            // visionOS puts the sheet on glass, an opaque plate on top of it would hide that
            .background { MyBackgroundColor(macOS: false) }
            .tint(theme.color)
            .interactiveDismissDisabled(!dismissable)
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
    /// Off for a neutral, gray button, e.g. closing without a selection
    let prominent: Bool
    let action: () -> Void

    init(_ title: LocalizedStringKey, prominent: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        Group {
            if prominent {
                button
                    .buttonStyle(.borderedProminent)
                    .tint(theme.color)
                    .foregroundStyle(theme.contrastColor)
            } else {
                button
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .foregroundStyle(.primary)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.top, 8)
    }

    var button: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
    }
}

struct OnboardingSearchBar: View {
    @Binding var text: String
    var prompt: LocalizedStringKey = "onboardingSearchChannels"
    var isSearching = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, isActive: isSearching)

            TextField(prompt, text: $text)
                .autocorrectionDisabled(true)
                #if os(iOS)
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.never)
                #endif
                .submitLabel(.search)
                .textFieldStyle(.plain)

            TextFieldClearButton(text: $text)
        }
        .padding(.horizontal, 14)
        .frame(height: OnboardingLayout.controlHeight)
        // the bar behind it is already a material on visionOS; an opaque fill reads as a dark blob
        #if os(visionOS)
        .background(.quaternary, in: Capsule())
        #else
        .background(Color.insetBackgroundColor, in: Capsule())
        #endif
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.top, 8)
    }
}
