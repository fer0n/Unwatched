//
//  OnboardingChannelsPage.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct OnboardingChannelsPage: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let channels = viewModel.listedChannels
        let firstId = channels.first?.id

        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(channels) { channel in
                    OnboardingChannelRow(
                        channel: channel,
                        isSelected: viewModel.isSelected(channel),
                        showsDivider: channel.id != firstId
                    ) {
                        withAnimation {
                            viewModel.toggle(channel)
                        }
                    }
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                }
            }
            .padding(.vertical, 6)
            .background(Color.backgroundColor)
        }
        .scrollDismissesKeyboard(.interactively)
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
        .background(Color.insetBackgroundColor, in: Capsule())
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.top, 8)
    }
}

#Preview {
    OnboardingChannelsPage(viewModel: OnboardingViewModel())
        .environment(ImageCacheManager())
        .modelContainer(DataProvider.previewContainer)
}
