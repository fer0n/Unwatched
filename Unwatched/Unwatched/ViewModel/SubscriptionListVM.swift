//
//  SubscriptionListVM.swift
//  Unwatched
//

import SwiftData
import OSLog
import SwiftUI
import UnwatchedShared

@Observable
class SubscriptionListVM: TransactionVM<Subscription> {
    @MainActor
    var allSubscriptions = [SendableSubscription]()

    @MainActor
    var subscriptions = [SendableSubscription]()

    @MainActor
    var isLoading = true

    @ObservationIgnored private var filterTask: Task<Void, Never>?
    private var sort = [SortDescriptor<Subscription>]()

    @MainActor
    private func fetchSubscriptions() async {
        let subs = await SubscriptionService.getActiveSubscriptions(nil, sort)
        withAnimation {
            allSubscriptions = subs
            isLoading = false
        }
        applyFilter(searchText: currentSearchText, to: subs)
    }

    @ObservationIgnored private var currentSearchText = ""

    @MainActor
    var hasNoSubscriptions: Bool {
        allSubscriptions.isEmpty && !isLoading
    }

    @MainActor
    func setSorting(_ sorting: SubscriptionSorting? = nil, refresh: Bool = false) {
        let sorting = {
            if let sorting = sorting {
                return sorting
            } else {
                let sortRaw = UserDefaults.standard.integer(forKey: Const.subscriptionSortOrder)
                return SubscriptionSorting(rawValue: sortRaw) ?? .recentlyAdded
            }
        }()
        switch sorting {
        case .title:
            self.sort = [SortDescriptor<Subscription>(\.title)]
        case .recentlyAdded:
            self.sort = [SortDescriptor<Subscription>(\.subscribedDate, order: .reverse)]
        case .mostRecentVideo:
            self.sort = [SortDescriptor<Subscription>(\.mostRecentVideoDate, order: .reverse)]
        }
        if refresh {
            Task {
                await updateData(force: true)
            }
        }
    }

    @MainActor
    func setSearchText(_ text: String) {
        currentSearchText = text
        applyFilter(searchText: text, to: allSubscriptions)
    }

    @MainActor
    private func applyFilter(searchText: String, to source: [SendableSubscription]) {
        filterTask?.cancel()
        guard !searchText.isEmpty else {
            subscriptions = source
            return
        }
        filterTask = Task.detached {
            let result = source.filter { $0.title.localizedStandardContains(searchText) }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation {
                    self.subscriptions = result
                }
            }
        }
    }

    @MainActor
    var countText: String {
        if isLoading {
            return ""
        }
        return "(\(subscriptions.count))"
    }

    @MainActor
    func updateData(force: Bool = false) async {
        var loaded = false
        if allSubscriptions.isEmpty || force {
            await fetchSubscriptions()
            loaded = true
        }
        let ids = await modelsHaveChangesUpdateToken()
        if loaded {
            return
        }
        if let ids = ids {
            updateSubscriptions(ids)
        } else {
            await fetchSubscriptions()
        }
    }

    @MainActor
    func updateSubscriptions(_ ids: Set<PersistentIdentifier>) {
        let modelContext = DataProvider.mainContext
        for persistentId in ids {
            guard let updatedSub: Subscription = modelContext.existingModel(for: persistentId) else {
                Log.warning("updateSubscription failed: no model found")
                continue
            }

            if let index = allSubscriptions.firstIndex(where: { $0.persistentId == persistentId }) {
                withAnimation {
                    if updatedSub.isArchived {
                        allSubscriptions.remove(at: index)
                    } else if let sendable = updatedSub.toExport {
                        allSubscriptions[index] = sendable
                    }
                }
                applyFilter(searchText: currentSearchText, to: allSubscriptions)
            } else {
                isLoading = true
                Task {
                    await fetchSubscriptions()
                }
                return
            }
        }
    }
}
