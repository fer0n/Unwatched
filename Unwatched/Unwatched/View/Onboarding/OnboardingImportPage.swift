//
//  OnboardingImportPage.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct OnboardingImportPage: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @Bindable var viewModel: OnboardingViewModel
    let source: Source
    let continueTitle: LocalizedStringKey
    let onContinue: () -> Void

    @State private var step = Step.loading
    @State private var loadAttempt = 0
    @State private var showLogin = false
    @State private var didSignIn = false
    @State private var accountNeedsRefresh = false
    @State private var searchText = ""
    @State private var subscribed = ActiveSubscriptions()

    enum Source: Hashable {
        case youtube
        case opml(URL)
    }

    enum Step: Equatable {
        case loading
        case loaded([OnboardingSearchResult])
        case empty
        case failed
    }

    var body: some View {
        let results = filteredResults
        let newResults = results.filter { !subscribed.contains($0) }
        let subscribedResults = results.filter(subscribed.contains)

        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(newResults) { result in
                    OnboardingResultRow(
                        result: result,
                        isSelected: viewModel.isSelected(result),
                        showsDivider: result.id != newResults.first?.id
                    ) {
                        viewModel.toggle(result)
                    }
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                }

                if !subscribedResults.isEmpty {
                    Text("alreadySubscribed")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, OnboardingLayout.horizontalPadding)
                        .padding(.top, newResults.isEmpty ? 8 : 24)
                        .padding(.bottom, 4)

                    ForEach(subscribedResults) { result in
                        OnboardingResultRow(
                            result: result,
                            isSelected: true,
                            showsDivider: result.id != subscribedResults.first?.id
                        ) { }
                        .disabled(true)
                        .padding(.horizontal, OnboardingLayout.horizontalPadding)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        #if !os(visionOS)
        .scrollDismissesKeyboard(.interactively)
        .scrollEdgeEffectStyle(.soft, for: .top)
        #endif
        .background {
            stateView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onboardingBottomBar(continueTitle, onContinue: onContinue) {
            OnboardingSearchBar(text: $searchText, prompt: "onboardingSearchImported")
        }
        .background { MyBackgroundColor(macOS: false) }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showLogin, onDismiss: handleLoginDismissed) {
            loginSheet
        }
        .task(id: loadAttempt) {
            await load()
        }
    }

    var title: LocalizedStringKey {
        switch source {
        case .youtube: "onboardingImportYoutube"
        case .opml: "onboardingImportPodcasts"
        }
    }

    var filteredResults: [OnboardingSearchResult] {
        guard case .loaded(let results) = step else { return [] }
        guard !searchText.isEmpty else { return results }
        return results.filter { $0.title.localizedStandardContains(searchText) }
    }

    @ViewBuilder
    var stateView: some View {
        switch step {
        case .loading:
            if !showLogin {
                ProgressView()
            }
        case .loaded:
            if filteredResults.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        case .empty:
            if source == .youtube {
                ContentUnavailableView(
                    "noYoutubeSubscriptionsFound",
                    systemImage: "person.crop.circle.badge.questionmark"
                )
            } else {
                ContentUnavailableView("nothingToImport", systemImage: "doc.questionmark")
            }
        case .failed where source != .youtube:
            ContentUnavailableView("fileReadFailed", systemImage: "exclamationmark.triangle")
        case .failed:
            ContentUnavailableView {
                Label("youtubeSubscriptionsLoadFailed", systemImage: "wifi.exclamationmark")
            } description: {
                Text("channelLoadFailedDescription")
            } actions: {
                Button("retry") {
                    loadAttempt += 1
                }
            }
        }
    }

    var loginSheet: some View {
        NavigationStack {
            YoutubeLoginWebView {
                didSignIn = true
                accountNeedsRefresh = true
                showLogin = false
                loadAttempt += 1
            }
            .ignoresSafeArea(edges: .bottom)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle("youtubeLogin")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel", role: .cancel) { showLogin = false }
                }
            }
        }
        #if os(macOS) || os(visionOS)
        .frame(minWidth: 450, minHeight: 600)
        #endif
    }

    func handleLoginDismissed() {
        if !didSignIn {
            dismiss()
        }
    }

    func load() async {
        withAnimation { step = .loading }
        do {
            let subscriptions = try await fetch()
            let results = subscriptions.compactMap(OnboardingSearchResult.init(subscription:))
            subscribed = ActiveSubscriptions(modelContext)
            withAnimation {
                step = results.isEmpty ? .empty : .loaded(results)
            }
        } catch is CancellationError {
            return
        } catch HomeFeedService.HomeFeedError.signedOut {
            didSignIn = false
            showLogin = true
        } catch {
            Log.error("onboarding: loading imported channels failed: \(error)")
            Signal.error("onboardingImportFailed")
            withAnimation { step = .failed }
        }
    }

    func fetch() async throws -> [SendableSubscription] {
        switch source {
        case .opml(let url):
            return try await Task.detached(priority: .userInitiated) {
                try OPMLParser.subscriptions(in: url)
            }.value
        case .youtube:
            if accountNeedsRefresh {
                accountNeedsRefresh = false
                await BrowserManager.shared.checkYoutubeLogin()
                HomeFeedService.shared.accountChanged()
            } else if await !BrowserManager.shared.isLoggedIntoYoutube() {
                throw HomeFeedService.HomeFeedError.signedOut
            }
            let subscriptions = try await HomeFeedService.shared.fetchSubscribedChannels()
            Signal.onboardingStep("youtubeImportLoaded", parameters: [
                "count": Signal.bucket(subscriptions.count)
            ])
            return subscriptions
        }
    }
}
