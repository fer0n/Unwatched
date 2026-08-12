//
//  OnboardingViewModel.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

@MainActor
@Observable final class OnboardingViewModel {
    var selected = [YoutubeChannelSearchResult]()
    var searchText = ""
    var searchResults = [YoutubeChannelSearchResult]()
    var isSearching = false
    var searchFailed = false

    /// Channels already subscribed to, so re-entering the first page doesn't subscribe twice
    private var subscribedChannelIds = Set<String>()
    /// Query `searchResults` belong to, so returning to the page doesn't re-run a finished search
    private var loadedQuery: String?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    var hideShorts = true

    private static let searchDebounce: Duration = .milliseconds(400)
    /// Cap on how long a refresh may be waited for, so onboarding can't get stuck on one
    private static let refreshTimeout: Duration = .seconds(30)

    var isSelectionEmpty: Bool {
        selected.isEmpty
    }

    /// Selected channels first, so one found via search stays reachable after the query changes.
    /// Stale results are dropped while a search is in flight.
    var listedChannels: [YoutubeChannelSearchResult] {
        let selectedIds = Set(selected.map(\.channelId))
        let rest: [YoutubeChannelSearchResult]
        if searchText.isEmpty {
            rest = OnboardingChannelSuggestions.all
        } else if isSearching {
            rest = []
        } else {
            rest = searchResults
        }
        return selected + rest.filter { !selectedIds.contains($0.channelId) }
    }

    func isSelected(_ channel: YoutubeChannelSearchResult) -> Bool {
        selected.contains { $0.channelId == channel.channelId }
    }

    func toggle(_ channel: YoutubeChannelSearchResult) {
        if let index = selected.firstIndex(where: { $0.channelId == channel.channelId }) {
            selected.remove(at: index)
        } else {
            selected.append(channel)
        }
    }

    /// Debounced so typing doesn't fire a request per keystroke. `isSearching` flips right away,
    /// hiding the previous query's results for the whole debounce + fetch.
    func searchDebounced() async {
        guard !searchText.isEmpty else {
            await search()
            return
        }
        guard searchText != loadedQuery else {
            return
        }
        isSearching = true
        try? await Task.sleep(for: Self.searchDebounce)
        guard !Task.isCancelled else { return }
        await search()
    }

    private func search() async {
        let raw = searchText
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            searchFailed = false
            isSearching = false
            loadedQuery = nil
            return
        }
        isSearching = true
        searchFailed = false
        do {
            let results = try await YoutubeChannelSearch.search(query)
            guard !Task.isCancelled else { return }
            searchResults = results
            searchFailed = results.isEmpty
        } catch {
            guard !Task.isCancelled else { return }
            Log.error("channelSearch failed: \(error)")
            searchResults = []
            searchFailed = true
        }
        isSearching = false
        loadedQuery = raw
    }

    /// Subscribes to everything picked so far and loads their videos, so the inbox is already
    /// filled by the time the last page is done. Awaitable via `waitForVideos()`.
    ///
    /// Runs again when the first page is continued a second time, unsubscribing whatever was
    /// deselected in between.
    func subscribeAndLoadVideos(_ refresher: RefreshManager) {
        let selectedIds = Set(selected.map(\.channelId))
        let newChannels = selected.filter { !subscribedChannelIds.contains($0.channelId) }
        let removedChannelIds = subscribedChannelIds.subtracting(selectedIds)
        guard !newChannels.isEmpty || !removedChannelIds.isEmpty else {
            return
        }
        subscribedChannelIds.formUnion(newChannels.map(\.channelId))
        subscribedChannelIds.subtract(removedChannelIds)

        let previousLoad = loadTask
        loadTask = Task {
            await previousLoad?.value
            // after the previous load, so its videos are there to be removed with the subscription
            for channelId in removedChannelIds {
                do {
                    try await SubscriptionService.unsubscribe(
                        SubscriptionInfo(channelId: channelId)
                    ).value
                } catch {
                    Log.error("onboarding unsubscribe failed: \(error)")
                }
            }
            guard !newChannels.isEmpty else {
                return
            }
            let info = newChannels.map {
                SubscriptionInfo(channelId: $0.channelId, userName: $0.userName)
            }
            do {
                _ = try await SubscriptionService.addSubscriptions(subscriptionInfo: info)
            } catch {
                Log.error("onboarding subscribe failed: \(error)")
                return
            }
            // refreshAll returns without doing anything while another refresh is in flight, and
            // that one started before these subscriptions existed
            await waitForRefresh(refresher)
            await refresher.refreshAll(firstTimeVideoLimit: Const.triageOnboardingSubs)
            await waitForRefresh(refresher)
        }
    }

    func waitForVideos() async {
        await loadTask?.value
    }

    private func waitForRefresh(_ refresher: RefreshManager) async {
        let deadline = ContinuousClock.now + Self.refreshTimeout
        while refresher.isLoading, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Clears the shorts the video load already put into the inbox. The setting itself is written
    /// by the view, so `CloudStorage` observers see the change.
    func cleanupShorts() async {
        guard hideShorts else {
            return
        }
        do {
            // passed in rather than read back: the setting travels via iCloud's key-value store,
            // which may not have it yet
            let count = try await CleanupService.cleanupHiddenShorts(defaultHideShorts: true).value
            Log.info("onboarding: cleaned up \(count) shorts")
        } catch {
            Log.error("onboarding shorts cleanup failed: \(error)")
        }
    }
}
