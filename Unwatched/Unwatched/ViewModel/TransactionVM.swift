//
//  TransactionVM.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared
import SwiftUI
import OSLog

/// Persists SwiftData history tokens across launches, keyed by model type.
///
/// Without a persisted token every cold launch reads the whole persistent history table,
/// which the app never prunes — installs have been measured at >140k transactions.
enum HistoryTokenStore {
    static func token(forModel model: String) -> DefaultHistoryToken? {
        guard let data = storedTokens()[model] else {
            return nil
        }
        return try? JSONDecoder().decode(DefaultHistoryToken.self, from: data)
    }

    static func setToken(_ token: DefaultHistoryToken, forModel model: String) {
        guard let data = try? JSONEncoder().encode(token) else {
            Log.error("setToken: failed to encode history token for \(model)")
            return
        }
        var tokens = storedTokens()
        tokens[model] = data
        UserDefaults.standard.set(tokens, forKey: Const.historyTokens)
    }

    static func removeToken(forModel model: String) {
        var tokens = storedTokens()
        tokens[model] = nil
        UserDefaults.standard.set(tokens, forKey: Const.historyTokens)
    }

    /// Oldest token across all lists: history before this has been seen by every consumer.
    static func lowestToken() -> DefaultHistoryToken? {
        storedTokens().values
            .compactMap { try? JSONDecoder().decode(DefaultHistoryToken.self, from: $0) }
            .min()
    }

    private static func storedTokens() -> [String: Data] {
        UserDefaults.standard.dictionary(forKey: Const.historyTokens) as? [String: Data] ?? [:]
    }
}

enum HistoryMaintenance {
    /// CloudKit tracks pending exports through the same history table, so transactions are
    /// only dropped once they are far older than any plausible sync lag. 7 days is the window
    /// Apple uses in "Consuming relevant store changes"; they document no CloudKit-specific
    /// guidance, so the token check below is what actually keeps unsynced changes safe.
    static let retentionDays = 7

    static func pruneConsumedHistory() {
        guard let token = HistoryTokenStore.lowestToken(),
              let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: .now) else {
            return
        }

        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        descriptor.predicate = #Predicate {
            $0.token < token && $0.timestamp < cutoff
        }

        do {
            let context = DataProvider.newContext()
            try context.deleteHistory(descriptor)
            Log.info("pruneConsumedHistory: pruned before \(cutoff)")
        } catch {
            Log.error("pruneConsumedHistory: \(error)")
        }
    }
}

@Observable class TransactionVM<T: PersistentModel> {
    @ObservationIgnored
    var historyToken: DefaultHistoryToken? {
        get {
            HistoryTokenStore.token(forModel: Self.modelKey)
        }
        set {
            guard let newValue else {
                return
            }
            HistoryTokenStore.setToken(newValue, forModel: Self.modelKey)
        }
    }

    private static var modelKey: String {
        String(describing: T.self)
    }

    static func findTransactions(after token: DefaultHistoryToken?) -> [DefaultHistoryTransaction] {
        do {
            return try fetchTransactions(after: token)
        } catch let error {
            guard (error as? SwiftDataError) == .historyTokenExpired else {
                Log.error("findTransactions: \(error)")
                return []
            }
            // the bookmarked transaction is gone from the stream, so resync from what's left
            Log.info("findTransactions: history token expired, resetting")
            HistoryTokenStore.removeToken(forModel: modelKey)
            return (try? fetchTransactions(after: nil)) ?? []
        }
    }

    private static func fetchTransactions(after token: DefaultHistoryToken?) throws -> [DefaultHistoryTransaction] {
        var historyDescriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        if let token {
            historyDescriptor.predicate = #Predicate { transaction in
                (transaction.token > token)
            }
        }

        return try DataProvider.newContext().fetchHistory(historyDescriptor)
    }

    static func getModelUpdates(_ transactions: [DefaultHistoryTransaction]) -> Set<PersistentIdentifier>? {
        var result: Set<PersistentIdentifier> = []
        for transaction in transactions {
            for change in transaction.changes {
                let modelID = change.changedPersistentIdentifier

                switch change {
                case .insert(_ as DefaultHistoryInsert<T>):
                    return nil
                case .update(_ as DefaultHistoryUpdate<T>):
                    result.insert(modelID)
                case .delete(_ as DefaultHistoryDelete<T>):
                    return nil
                default: break
                }
            }
        }
        return result
    }

    @MainActor
    func modelsHaveChangesUpdateToken() async -> Set<PersistentIdentifier>? {
        let token = historyToken
        let task = Task.detached {
            var modelUpdates: Set<PersistentIdentifier>?
            let transactions = TransactionVM.findTransactions(after: token)
            Log.info("modelsHaveChanges: \(transactions.count)")
            if transactions.count <= 20 {
                // if there's more than 20 changes, simply fetch everything
                modelUpdates = TransactionVM.getModelUpdates(transactions)
            }
            return (transactions.last?.token, modelUpdates)
        }
        let (newToken, modelUpdates) = await task.value
        if let newToken {
            historyToken = newToken
        }
        return modelUpdates
    }
}
