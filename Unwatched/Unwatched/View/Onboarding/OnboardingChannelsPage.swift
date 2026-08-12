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

                if viewModel.searchFailed && !viewModel.isSearching {
                    Text("onboardingNoChannelsFound")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, OnboardingLayout.horizontalPadding)
                        .padding(.vertical, 6)
                }
            }
            .padding(.vertical, 6)
        }
        .scrollDismissesKeyboard(.interactively)
        .task(id: viewModel.searchText) {
            await viewModel.searchDebounced()
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
