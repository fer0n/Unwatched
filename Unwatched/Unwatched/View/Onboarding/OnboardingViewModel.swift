//
//  OnboardingViewModel.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

@MainActor
@Observable final class OnboardingViewModel {
    var selected = [OnboardingSearchResult]()
    var searchText = ""
    var searchResults = [OnboardingSearchResult]()
    var isSearching = false
    var searchState = SearchState.idle

    enum SearchState: Equatable {
        case idle
        /// The search ran and matched nothing
        case noResults
        /// The search couldn't run: no connection, or neither source answered with results
        case failed
    }

    /// Written by `OnboardingViewModel+Search`, read-only everywhere else
    var didSearch = false
    /// Query `searchResults` belong to, so returning to the page doesn't re-run a finished search
    var loadedQuery: String?

    /// Results already subscribed to, keyed by `id`, so re-entering the first page doesn't
    /// subscribe twice and a later unselect knows what to unsubscribe from
    private var subscribedResults = [String: OnboardingSearchResult]()
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    var hideShorts = true

    /// Cap on how long a refresh may be waited for, so onboarding can't get stuck on one
    private static let refreshTimeout: Duration = .seconds(30)

    var isSelectionEmpty: Bool {
        selected.isEmpty
    }

    /// A search shows only its own results — a selected result that doesn't match stays selected
    /// but drops out of view. Without one, selected results the curated list doesn't hold go
    /// first, so one found via search stays reachable after the query is cleared.
    var listedResults: [OnboardingSearchResult] {
        guard searchText.isEmpty else {
            // stale results are dropped while a search is in flight
            return isSearching ? [] : searchResults
        }
        return selected.filter { !OnboardingSearchSuggestions.allIds.contains($0.id) }
            + OnboardingSearchSuggestions.all
    }

    func isSelected(_ result: OnboardingSearchResult) -> Bool {
        selected.contains { $0.id == result.id }
    }

    func toggle(_ result: OnboardingSearchResult) {
        if let index = selected.firstIndex(where: { $0.id == result.id }) {
            selected.remove(at: index)
        } else {
            selected.append(result)
        }
    }

    /// Subscribes to everything picked so far and loads their videos, so the inbox is already
    /// filled by the time the last page is done. Awaitable via `waitForVideos()`.
    ///
    /// Runs again when the first page is continued a second time, unsubscribing whatever was
    /// deselected in between.
    func subscribeAndLoadVideos(_ refresher: RefreshManager) {
        let selectedIds = Set(selected.map(\.id))
        let newResults = selected.filter { subscribedResults[$0.id] == nil }
        let removedResults = subscribedResults.values.filter { !selectedIds.contains($0.id) }
        guard !newResults.isEmpty || !removedResults.isEmpty else {
            return
        }
        for result in newResults {
            subscribedResults[result.id] = result
        }
        for result in removedResults {
            subscribedResults.removeValue(forKey: result.id)
        }

        let previousLoad = loadTask
        loadTask = Task {
            await previousLoad?.value
            // after the previous load, so its videos are there to be removed with the subscription
            for result in removedResults {
                do {
                    try await Self.unsubscribe(result)
                } catch {
                    Log.error("onboarding unsubscribe failed: \(error)")
                }
            }
            guard !newResults.isEmpty else {
                return
            }
            do {
                try await Self.subscribe(newResults)
            } catch {
                Log.error("onboarding subscribe failed: \(error)")
                Signal.error("onboardingSubscribeFailed")
                return
            }
            // refreshAll returns without doing anything while another refresh is in flight, and
            // that one started before these subscriptions existed
            await waitForRefresh(refresher)
            await refresher.refreshAll(firstTimeVideoLimit: Const.triageOnboardingSubs)
            await waitForRefresh(refresher)
        }
    }

    private static func subscribe(_ results: [OnboardingSearchResult]) async throws {
        let channels = results.compactMap(\.channel)
        if !channels.isEmpty {
            let info = channels.map {
                SubscriptionInfo(channelId: $0.channelId, userName: $0.userName)
            }
            _ = try await SubscriptionService.addSubscriptions(subscriptionInfo: info)
        }
        let podcasts = results.compactMap(\.podcast)
        if !podcasts.isEmpty {
            _ = try await SubscriptionService.addSubscriptions(from: podcasts)
        }
    }

    private static func unsubscribe(_ result: OnboardingSearchResult) async throws {
        switch result {
        case .channel(let channel):
            try await SubscriptionService.unsubscribe(
                SubscriptionInfo(channelId: channel.channelId)
            ).value
        case .podcast(let podcast):
            guard let link = podcast.link else { return }
            try await SubscriptionService.unsubscribeFromPodcast(link)
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
