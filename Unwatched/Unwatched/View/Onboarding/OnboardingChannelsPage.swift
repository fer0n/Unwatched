//
//  OnboardingChannelsPage.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct OnboardingChannelsPage: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let results = viewModel.listedResults
        let firstId = results.first?.id

        ScrollView {
            LazyVStack(spacing: 0) {
                OnboardingHeader(
                    title: "onboardingChannelsTitle",
                    description: viewModel.searchText.isEmpty ? "onboardingChannelsDescription" : nil
                )

                ForEach(results) { result in
                    OnboardingResultRow(
                        result: result,
                        isSelected: viewModel.isSelected(result),
                        showsDivider: result.id != firstId
                    ) {
                        viewModel.toggle(result)
                    }
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                }
            }
            .padding(.bottom, 6)
            .background { MyBackgroundColor(macOS: false) }
        }
        #if !os(visionOS)
        .scrollDismissesKeyboard(.interactively)
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

struct OnboardingChannelsSearchBar: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, isActive: viewModel.isSearching)

            TextField("onboardingSearchChannels", text: $viewModel.searchText)
                .autocorrectionDisabled(true)
                #if os(iOS)
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.never)
                #endif
                .submitLabel(.search)
                .textFieldStyle(.plain)

            TextFieldClearButton(text: $viewModel.searchText)
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

#Preview {
    OnboardingChannelsPage(viewModel: OnboardingViewModel())
        .environment(ImageCacheManager())
        .modelContainer(DataProvider.previewContainer)
}
