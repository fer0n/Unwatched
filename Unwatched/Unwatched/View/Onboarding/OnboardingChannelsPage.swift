//
//  OnboardingChannelsPage.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct OnboardingChannelsPage: View {
    @Bindable var viewModel: OnboardingViewModel
    var onImportFromYoutube: () -> Void
    var onImportPodcasts: () -> Void

    var body: some View {
        let results = viewModel.listedResults
        let firstId = results.first?.id

        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.searchText.isEmpty {
                    OnboardingImportCards(
                        onImportFromYoutube: onImportFromYoutube,
                        onImportPodcasts: onImportPodcasts
                    )
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                    .padding(.top, 8)
                }

                ForEach(results) { result in
                    OnboardingResultRow(
                        result: result,
                        isSelected: viewModel.isSelected(result),
                        showsDivider: result.id != firstId
                    ) {
                        withAnimation { viewModel.toggle(result) }
                    }
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                }
            }
            .padding(.bottom, 6)
            .background { MyBackgroundColor(macOS: false) }
        }
        #if !os(visionOS)
        .scrollDismissesKeyboard(.interactively)
        .scrollEdgeEffectStyle(.soft, for: .top)
        #endif
        .background {
            ZStack {
                if let state = visibleSearchState {
                    searchStateView(state)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.bouncy, value: visibleSearchState)
        }
        .task(id: viewModel.searchText) {
            await viewModel.searchDebounced()
        }
    }

    /// Nil while there's nothing to say about the current search, including while one is running
    private var visibleSearchState: OnboardingViewModel.SearchState? {
        guard !viewModel.isSearching, viewModel.searchState != .idle else {
            return nil
        }
        return viewModel.searchState
    }

    @ViewBuilder
    func searchStateView(_ state: OnboardingViewModel.SearchState) -> some View {
        switch state {
        case .idle:
            EmptyView()
        case .noResults:
            ContentUnavailableView(
                "onboardingNoChannelsFound",
                systemImage: "magnifyingglass"
            )
        case .failed:
            ContentUnavailableView {
                Label("searchFailed", systemImage: "wifi.exclamationmark")
            } description: {
                Text("channelLoadFailedDescription")
            } actions: {
                Button("retry") {
                    Task {
                        await viewModel.retrySearch()
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingChannelsPage(viewModel: OnboardingViewModel(), onImportFromYoutube: { }, onImportPodcasts: { })
        .environment(ImageCacheManager())
        .modelContainer(DataProvider.previewContainer)
}
