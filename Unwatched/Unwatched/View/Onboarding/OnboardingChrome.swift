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
                        // on the page, not the ZStack: a layout container between the bar and the
                        // page's scroll view leaves the soft edge effect at a default height
                        .softSafeAreaBar(edge: .top) {
                            OnboardingHeader(page: candidate, title: title, description: description)
                                .onboardingBarBackdrop()
                        }
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
        .softSafeAreaBar(edge: .bottom) {
            VStack(spacing: 0) {
                accessory()
                OnboardingContinueButton(continueTitle, isLoading: isLoading, action: onContinue)
                OnboardingPageIndicator(pages: pages, page: page)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .onboardingBarBackdrop()
        }
        .setColorScheme()
        // visionOS puts the sheet on glass, an opaque plate on top of it would hide that
        .background { MyBackgroundColor(macOS: false) }
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

private extension View {
    /// visionOS has no scroll edge effect, so the list would scroll visibly through the bar.
    func onboardingBarBackdrop() -> some View {
        self
            #if os(visionOS)
            // the header is only as wide as its text, the backdrop has to span the sheet
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        #endif
    }
}

struct OnboardingHeader<Page: Hashable>: View {
    let page: Page
    let title: (Page) -> LocalizedStringKey
    let description: (Page) -> LocalizedStringKey?

    var body: some View {
        VStack(spacing: 0) {
            Text(title(page))
                .font(.title)
                .fontWeight(.bold)
                // the soft edge effect only blurs the first line, so a second one would sit
                // on sharp rows
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 30)
                .padding(.top, 28)

            if let text = description(page) {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 6)
            }
        }
        .padding(.bottom, 12)
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
