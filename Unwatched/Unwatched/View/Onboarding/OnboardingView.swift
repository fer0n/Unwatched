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

struct OnboardingView: View {
    @AppStorage(Const.onboardingCompleted) var onboardingCompleted = false
    @AppStorage(Const.onboardingStarted) var onboardingStarted = false
    @AppStorage(Const.settingsSplashShown) var settingsSplashShown = false

    @Environment(RefreshManager.self) var refresher
    @Environment(NavigationManager.self) var navManager
    @Environment(\.dismiss) var dismiss

    @Bindable var viewModel: OnboardingViewModel
    @State private var importSource: OnboardingImportPage.Source?
    @State private var showOpmlPicker = false
    @State private var usedImport: String?
    @State private var hasSubscriptions = false

    var body: some View {
        NavigationStack {
            OnboardingChannelsPage(viewModel: viewModel) {
                openImport(.youtube)
            } onImportPodcasts: {
                showOpmlPicker = true
            }
            .onboardingBottomBar(continueTitle, onContinue: handleContinue) {
                OnboardingSearchBar(text: $viewModel.searchText, isSearching: viewModel.isSearching)
            }
            .navigationTitle("onboardingChannelsTitle")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if hasSubscriptions {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("cancel", role: .cancel) { dismiss() }
                    }
                }
            }
            .navigationDestination(item: $importSource) { source in
                OnboardingImportPage(
                    viewModel: viewModel,
                    source: source,
                    continueTitle: continueTitle,
                    onContinue: handleContinue
                )
            }
        }
        .onboardingSheetStyle(dismissable: hasSubscriptions)
        .task {
            hasSubscriptions = (await SubscriptionService.getActiveSubscriptionCount().value ?? 0) > 0
        }
        .fileImporter(isPresented: $showOpmlPicker, allowedContentTypes: [.opml, .xml]) { result in
            if let url = try? result.get() {
                openImport(.opml(url))
            }
        }
        .onAppear {
            guard viewModel.isFirstRun else { return }
            if !onboardingStarted {
                Signal.onboardingStep("started")
            }
            onboardingStarted = true
        }
    }

    var continueTitle: LocalizedStringKey {
        viewModel.isSelectionEmpty ? "onboardingSkip" : "onboardingShowInbox"
    }

    func handleContinue() {
        if viewModel.isFirstRun {
            Signal.onboardingStep("channels", parameters: [
                "selected": Signal.bucket(viewModel.selected.count),
                "usedSearch": Signal.onOff(viewModel.didSearch)
            ])
            Signal.onboardingStep("finished", parameters: ["via": usedImport ?? "channels"])
            settingsSplashShown = true
            OnboardingInboxTip.onboardingFinished = true
        }
        viewModel.subscribeAndRefresh(refresher)
        onboardingCompleted = true
        navManager.navigateTo(.inbox)
        dismiss()
    }

    func openImport(_ source: OnboardingImportPage.Source) {
        usedImport = source == .youtube ? "youtubeImport" : "podcastImport"
        if viewModel.isFirstRun {
            Signal.onboardingStep(source == .youtube ? "youtubeImportOpened" : "podcastImportOpened")
        }
        importSource = source
    }
}

extension View {
    func onboardingSheet(isPresented: Binding<Bool>, viewModel: OnboardingViewModel) -> some View {
        sheet(isPresented: isPresented) {
            OnboardingView(viewModel: viewModel)
                .onboardingSheetFrame()
        }
    }

    func onboardingSheetFrame() -> some View {
        #if os(macOS) || os(visionOS)
        self.frame(height: 650).frame(minWidth: 450)
        #else
        self
        #endif
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            OnboardingView(viewModel: OnboardingViewModel(isFirstRun: true))
        }
        .modelContainer(DataProvider.previewContainer)
        .environment(RefreshManager())
        .environment(NavigationManager())
        .environment(ImageCacheManager())
}
