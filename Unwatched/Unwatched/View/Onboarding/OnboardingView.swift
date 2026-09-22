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
/// land in the inbox.
struct OnboardingView: View {
    @AppStorage(Const.onboardingCompleted) var onboardingCompleted = false
    @AppStorage(Const.onboardingStarted) var onboardingStarted = false
    @AppStorage(Const.settingsSplashShown) var settingsSplashShown = false

    @Environment(RefreshManager.self) var refresher
    @Environment(NavigationManager.self) var navManager
    @Environment(\.dismiss) var dismiss

    @State private var viewModel = OnboardingViewModel()
    @State private var isFinishing = false

    var body: some View {
        OnboardingChannelsPage(viewModel: viewModel)
            .onboardingBottomBar(continueTitle, isLoading: isFinishing, onContinue: handleContinue) {
                OnboardingChannelsSearchBar(viewModel: viewModel)
            }
            .onboardingSheetStyle()
            .onAppear {
                if !onboardingStarted {
                    Signal.onboardingStep("started")
                }
                // from here on the flow returns on every launch until `finish()` runs
                onboardingStarted = true
            }
    }

    var continueTitle: LocalizedStringKey {
        viewModel.isSelectionEmpty ? "onboardingSkip" : "onboardingShowInbox"
    }

    func handleContinue() {
        Signal.onboardingStep("channels", parameters: [
            "selected": Signal.bucket(viewModel.selected.count),
            "usedSearch": Signal.onOff(viewModel.didSearch)
        ])
        viewModel.subscribeAndLoadVideos(refresher)
        finish()
    }

    func finish() {
        isFinishing = true
        Task {
            // so the inbox is complete before it becomes visible
            await viewModel.waitForVideos()

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
