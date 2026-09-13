//
//  OnboardingChrome.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct OnboardingPager<Page: Hashable, Content: View, Accessory: View>: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    let pages: [Page]
    @Binding var page: Page
    let title: (Page) -> LocalizedStringKey
    let description: (Page) -> LocalizedStringKey?
    let continueTitle: LocalizedStringKey
    var isLoading = false
    let onContinue: () -> Void
    @ViewBuilder let content: (Page) -> Content
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        // not a horizontal ScrollView: the soft scroll edge effect needs each page's own ScrollView
        ZStack {
            ForEach(pages, id: \.self) { candidate in
                if candidate == page {
                    content(candidate)
                        .transition(.move(edge: candidate == pages.first ? .leading : .trailing))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard value.translation.width > 50, let previousPage else { return }
                    withAnimation {
                        page = previousPage
                    }
                },
            including: previousPage == nil ? .none : .all
        )
        .softSafeAreaBar(edge: .top) {
            OnboardingHeader(pages: pages, page: page, title: title, description: description)
        }
        .softSafeAreaBar(edge: .bottom) {
            VStack(spacing: 0) {
                accessory()
                OnboardingContinueButton(continueTitle, isLoading: isLoading, action: onContinue)
                OnboardingPageIndicator(pages: pages, page: page)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .setColorScheme()
        .background(Color.backgroundColor)
        .tint(theme.color)
        .interactiveDismissDisabled()
        .sensoryFeedback(Const.sensoryFeedback, trigger: page)
    }

    private var previousPage: Page? {
        guard let index = pages.firstIndex(of: page), index > 0 else {
            return nil
        }
        return pages[index - 1]
    }
}

extension OnboardingPager where Accessory == EmptyView {
    init(
        pages: [Page],
        page: Binding<Page>,
        title: @escaping (Page) -> LocalizedStringKey,
        description: @escaping (Page) -> LocalizedStringKey?,
        continueTitle: LocalizedStringKey,
        onContinue: @escaping () -> Void,
        @ViewBuilder content: @escaping (Page) -> Content
    ) {
        self.init(
            pages: pages,
            page: page,
            title: title,
            description: description,
            continueTitle: continueTitle,
            onContinue: onContinue,
            content: content,
            accessory: { EmptyView() }
        )
    }
}

struct OnboardingHeader<Page: Hashable>: View {
    let pages: [Page]
    let page: Page
    let title: (Page) -> LocalizedStringKey
    let description: (Page) -> LocalizedStringKey?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title(page))
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .id(page)
                    .transition(.opacity)
            }
            .frame(height: 38)
            .padding(.top, 28)

            // all descriptions stay mounted, so the container keeps the height of the longest
            ZStack(alignment: .top) {
                ForEach(pages, id: \.self) { candidate in
                    if let text = description(candidate) {
                        Text(text)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .opacity(candidate == page ? 1 : 0)
                            .accessibilityHidden(candidate != page)
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .animation(.easeInOut(duration: 0.2), value: page)
    }
}

struct OnboardingPageIndicator<Page: Hashable>: View {
    let pages: [Page]
    let page: Page

    var body: some View {
        HStack(spacing: 6) {
            ForEach(pages, id: \.self) { candidate in
                Circle()
                    .fill(candidate == page ? Color.secondary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.2), value: page)
    }
}

struct OnboardingContinueButton: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    let title: LocalizedStringKey
    let isLoading: Bool
    let action: () -> Void

    init(_ title: LocalizedStringKey, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
        }
        .disabled(isLoading)
        .buttonStyle(.borderedProminent)
        .tint(theme.color)
        .foregroundStyle(theme.contrastColor)
        .controlSize(.large)
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.top, 8)
    }
}
