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

    func subscribeAndRefresh(_ refresher: RefreshManager) {
        let results = selected
        guard !results.isEmpty else {
            return
        }
        Task {
            do {
                try await Self.subscribe(results)
            } catch {
                Log.error("onboarding subscribe failed: \(error)")
                Signal.error("onboardingSubscribeFailed")
                return
            }
            // refreshAll does nothing while another refresh is in flight
            await Self.waitForRefresh(refresher)
            await refresher.refreshAll()
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

    private static func waitForRefresh(_ refresher: RefreshManager) async {
        let deadline = ContinuousClock.now + refreshTimeout
        while refresher.isLoading, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
