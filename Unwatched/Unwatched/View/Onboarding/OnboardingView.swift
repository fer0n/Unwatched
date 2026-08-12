//
//  OnboardingView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

enum OnboardingLayout {
    /// shared by every onboarding page and bar, so the search bar lines up with the list it filters
    static let horizontalPadding: CGFloat = 20
    /// hand-matched to a `.large` bordered button, so search bar and continue button match
    static let controlHeight: CGFloat = 50
}

/// First-launch flow that gets a new user from an empty app to a filled inbox: pick channels,
/// decide on shorts, land in the inbox.
struct OnboardingView: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @AppStorage(Const.onboardingCompleted) var onboardingCompleted = false
    @AppStorage(Const.onboardingStarted) var onboardingStarted = false
    @CloudStorage(Const.defaultShortsSetting) var defaultShortsSetting: ShortsSetting = .show

    @Environment(RefreshManager.self) var refresher
    @Environment(NavigationManager.self) var navManager
    @Environment(\.dismiss) var dismiss

    @State private var viewModel = OnboardingViewModel()
    @State private var page: OnboardingPage = .channels
    @State private var isFinishing = false

    private enum OnboardingPage: CaseIterable, Hashable, Sendable {
        case channels
        case shorts

        var title: LocalizedStringKey {
            switch self {
            case .channels: return "onboardingChannelsTitle"
            case .shorts: return "onboardingShortsTitle"
            }
        }

        var description: LocalizedStringKey {
            switch self {
            case .channels: return "onboardingChannelsDescription"
            case .shorts: return "onboardingShortsDescription"
            }
        }
    }

    var body: some View {
        // not a horizontal ScrollView: the bars need the page's own ScrollView directly beneath
        // them, otherwise the soft scroll edge effect never renders
        ZStack {
            switch page {
            case .channels:
                OnboardingChannelsPage(viewModel: viewModel)
                    .transition(.move(edge: .leading))
            case .shorts:
                OnboardingShortsPage(hideShorts: $viewModel.hideShorts)
                    .transition(.move(edge: .trailing))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard value.translation.width > 50 else { return }
                    withAnimation {
                        page = .channels
                    }
                },
            including: page == .shorts ? .all : .none
        )
        // declared here, not per page, so they don't slide with the pages
        .softSafeAreaBar(edge: .top) {
            header
        }
        .softSafeAreaBar(edge: .bottom) {
            VStack(spacing: 0) {
                if page == .channels {
                    OnboardingChannelsSearchBar(viewModel: viewModel)
                }
                continueButton
                // lets the dots take over the home indicator strip where there is one
                pageIndicator
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .setColorScheme()
        .background(Color.backgroundColor)
        .tint(theme.color)
        .interactiveDismissDisabled()
        .sensoryFeedback(Const.sensoryFeedback, trigger: page)
        .onAppear {
            // from here on the flow returns on every launch until `finish()` runs
            onboardingStarted = true
        }
    }

    var header: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(page.title)
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
                ForEach(OnboardingPage.allCases, id: \.self) { candidate in
                    Text(candidate.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .opacity(candidate == page ? 1 : 0)
                        .accessibilityHidden(candidate != page)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .animation(.easeInOut(duration: 0.2), value: page)
    }

    var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingPage.allCases, id: \.self) { candidate in
                Circle()
                    .fill(candidate == page ? Color.secondary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.2), value: page)
    }

    var continueButton: some View {
        Button(action: handleContinue) {
            HStack(spacing: 8) {
                Text(continueTitle)
                if isFinishing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
        }
        .disabled(isFinishing)
        .buttonStyle(.borderedProminent)
        .tint(theme.color)
        .foregroundStyle(theme.contrastColor)
        .controlSize(.large)
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.top, 8)
    }

    var continueTitle: LocalizedStringKey {
        switch page {
        case .channels: return viewModel.isSelectionEmpty ? "onboardingSkip" : "onboardingContinue"
        case .shorts: return "onboardingShowInbox"
        }
    }

    func handleContinue() {
        switch page {
        case .channels:
            // not awaited: the videos load while the shorts page is on screen
            viewModel.subscribeAndLoadVideos(refresher)
            withAnimation {
                page = .shorts
            }
        case .shorts:
            finish()
        }
    }

    func finish() {
        isFinishing = true
        defaultShortsSetting = viewModel.hideShorts ? .hide : .show
        Task {
            // so the inbox is complete and its shorts are gone before it becomes visible
            await viewModel.waitForVideos()
            await viewModel.cleanupShorts()

            onboardingCompleted = true
            OnboardingInboxTip.onboardingFinished = true
            navManager.navigateTo(.inbox)
            isFinishing = false
            dismiss()
        }
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            OnboardingView()
        }
        .modelContainer(DataProvider.previewContainer)
        .environment(RefreshManager())
        .environment(NavigationManager())
        .environment(ImageCacheManager())
}
