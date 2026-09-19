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
    @AppStorage(Const.onboardingCompleted) var onboardingCompleted = false
    @AppStorage(Const.onboardingStarted) var onboardingStarted = false
    @AppStorage(Const.settingsSplashShown) var settingsSplashShown = false
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

        /// `nil` for `.channels`: that page shows its own description inline, scrolling away
        /// with the list instead of sitting in the fixed header
        var description: LocalizedStringKey? {
            switch self {
            case .channels: return nil
            case .shorts: return "onboardingShortsDescription"
            }
        }
    }

    var body: some View {
        OnboardingPager(
            pages: OnboardingPage.allCases,
            page: $page,
            title: { $0.title },
            description: { $0.description },
            continueTitle: continueTitle,
            isLoading: isFinishing,
            onContinue: handleContinue
        ) {
            switch $0 {
            case .channels: OnboardingChannelsPage(viewModel: viewModel)
            case .shorts: OnboardingShortsPage(hideShorts: $viewModel.hideShorts)
            }
        } accessory: {
            if page == .channels {
                OnboardingChannelsSearchBar(viewModel: viewModel)
            }
        }
        .onAppear {
            if !onboardingStarted {
                Signal.onboardingStep("started")
            }
            // from here on the flow returns on every launch until `finish()` runs
            onboardingStarted = true
        }
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
            Signal.onboardingStep("channels", parameters: [
                "selected": Signal.bucket(viewModel.selected.count),
                "usedSearch": Signal.onOff(viewModel.didSearch)
            ])
            // not awaited: the videos load while the shorts page is on screen
            viewModel.subscribeAndLoadVideos(refresher)
            withAnimation {
                page = .shorts
            }
        case .shorts:
            Signal.onboardingStep("shorts", parameters: [
                "hideShorts": Signal.onOff(viewModel.hideShorts)
            ])
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

            Signal.onboardingStep("finished")
            onboardingCompleted = true
            settingsSplashShown = true
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
