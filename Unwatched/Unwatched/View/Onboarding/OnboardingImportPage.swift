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
    let onContinue: () -> Void

    @State private var step = Step.loading
    @State private var loadAttempt = 0
    @State private var showLogin = false
    @State private var didSignIn = false
    @State private var accountNeedsRefresh = false
    @State private var searchText = ""
    @State private var subscribed = ActiveSubscriptions()
    @State private var uploadRates = ChannelUploadRates()
    @CloudStorage(Const.defaultShortsSetting) private var defaultShortsSetting: ShortsSetting = .show
    @State private var inboxShortsCount: Int?

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
        let newResults = selectableResults
        let subscribedResults = filteredResults.filter(subscribed.contains)

        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(newResults) { result in
                    let channelId = showsUploadRates ? result.channel?.channelId : nil
                    OnboardingResultRow(
                        result: result,
                        isSelected: viewModel.isSelected(result),
                        showsDivider: result.id != newResults.first?.id,
                        uploadRateText: channelId.map { uploadRateText(uploadRates.rates[$0]) }
                    ) {
                        withAnimation { viewModel.toggle(result) }
                    }
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                    .task {
                        if let channelId {
                            await uploadRates.load(channelId: channelId)
                        }
                    }
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
        .onboardingBottomBar(
            viewModel.continueTitle,
            prominent: !viewModel.isSelectionEmpty,
            detail: showsUploadRates && !viewModel.isSelectionEmpty ? selectionUploadRateText : nil,
            onContinue: onContinue
        ) {
            OnboardingSearchBar(text: $searchText, prompt: "onboardingSearchImported")
        }
        .background { MyBackgroundColor(macOS: false) }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                moreMenu
            }
        }
        .sheet(isPresented: $showLogin, onDismiss: handleLoginDismissed) {
            loginSheet
        }
        .task(id: loadAttempt) {
            await load()
        }
        .task(id: selectedChannelIds) {
            if showsUploadRates {
                await uploadRates.load(channelIds: selectedChannelIds)
            }
        }
        .confirmationDialog(
            "removeShortsFromInbox",
            isPresented: Binding(get: { inboxShortsCount != nil }, set: { if !$0 { inboxShortsCount = nil } }),
            titleVisibility: .visible
        ) {
            Button("removeShortsFromInbox \(inboxShortsCount ?? 0)", role: .destructive) {
                VideoService.clearAllYtShortsFromInbox(modelContext)
            }
            Button("cancel", role: .cancel) { }
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
                    DismissSheetButton { showLogin = false }
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
            var results = subscriptions.compactMap(OnboardingSearchResult.init(subscription:))
            if source == .youtube && !results.isEmpty {
                results.insert(.watchLater, at: 0)
            }
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

extension OnboardingImportPage {
    var moreMenu: some View {
        Menu {
            let results = selectableResults
            let allSelected = !results.isEmpty && results.allSatisfy(viewModel.isSelected)
            Button(allSelected ? "deselectAll" : "selectAll") {
                withAnimation {
                    for result in results where viewModel.isSelected(result) == allSelected {
                        viewModel.toggle(result)
                    }
                }
            }
            .disabled(results.isEmpty)

            if showsUploadRates {
                Menu {
                    Section("onboardingShortsSettingInfo") {
                        ForEach([ShortsSetting.show, .hide], id: \.self) { setting in
                            Toggle(setting.description, isOn: shortsSettingBinding(setting))
                        }
                    }
                } label: {
                    Text("shortsSetting")
                    Text(defaultShortsSetting.description)
                }
            }
        } label: {
            Label("moreOptions", systemImage: "ellipsis")
        }
    }

    func shortsSettingBinding(_ setting: ShortsSetting) -> Binding<Bool> {
        Binding(
            get: { defaultShortsSetting == setting },
            set: { isOn in
                guard isOn else { return }
                defaultShortsSetting = setting
                if setting == .hide {
                    offerToClearInboxShorts()
                }
            }
        )
    }

    func offerToClearInboxShorts() {
        Task {
            if let count = await VideoService.inboxShortsCount().value, count > 0 {
                inboxShortsCount = count
            }
        }
    }

    var showsUploadRates: Bool {
        source == .youtube
    }

    var selectedChannelIds: [String] {
        viewModel.selected.compactMap(\.channel?.channelId)
    }

    var selectableResults: [OnboardingSearchResult] {
        filteredResults.filter { !subscribed.contains($0) }
    }

    func displayed(_ rate: UploadRate) -> UploadRate {
        defaultShortsSetting == .hide ? rate.withoutShorts : rate
    }

    func uploadRateText(_ rate: UploadRate?) -> String {
        rate.flatMap { displayed($0).localizedDescription } ?? " "
    }

    var selectionUploadRateText: String {
        let channelIds = selectedChannelIds
        guard uploadRates.hasLoaded(channelIds: channelIds) else { return "…" }
        return uploadRateText(uploadRates.total(channelIds: channelIds))
    }
}
