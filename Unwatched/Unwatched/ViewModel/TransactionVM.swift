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
@available(iOS 18, *)
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

    private static func storedTokens() -> [String: Data] {
        UserDefaults.standard.dictionary(forKey: Const.historyTokens) as? [String: Data] ?? [:]
    }
}

enum HistoryMaintenance {
    /// CloudKit tracks pending exports through the same history table, so transactions are
    /// only dropped once they are far older than any plausible sync lag. Matches the window
    /// used by Apple's own Core Data + CloudKit sample.
    static let retentionDays = 7

    /// Keeps each delete short enough not to stall the main thread behind the store's write lock
    static let chunkDays = 1

    @available(iOS 18, *)
    static func pruneConsumedHistory() async {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: .now),
              let oldest = oldestTransactionDate(),
              oldest < cutoff else {
            UserDefaults.standard.markPerformed(Const.cleanupHistoryTransactions)
            return
        }

        let context = DataProvider.newContext()
        var prunedUpTo = oldest
        do {
            while prunedUpTo < cutoff {
                prunedUpTo = min(
                    calendar.date(byAdding: .day, value: chunkDays, to: prunedUpTo) ?? cutoff,
                    cutoff
                )
                try deleteHistory(before: prunedUpTo, context: context)
                await Task.yield()
            }
            UserDefaults.standard.markPerformed(Const.cleanupHistoryTransactions)
            Log.info("pruneConsumedHistory: pruned before \(cutoff)")
        } catch {
            Log.error("pruneConsumedHistory: stopped at \(prunedUpTo): \(error)")
        }
    }

    @available(iOS 18, *)
    private static func oldestTransactionDate() -> Date? {
        // history is append-only, so the first transaction is the oldest (`sortBy` is iOS 26+)
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        descriptor.fetchLimit = 1
        let transactions = (try? DataProvider.newContext().fetchHistory(descriptor)) ?? []
        return transactions.first?.timestamp
    }

    @available(iOS 18, *)
    private static func deleteHistory(before date: Date, context: ModelContext) throws {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        descriptor.predicate = #Predicate {
            $0.timestamp < date
        }
        try context.deleteHistory(descriptor)
    }
}

@Observable class TransactionVM<T: PersistentModel> {
    @available(iOS 18.0, *)
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

    @available(iOS 18, *)
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

    @available(iOS 18, *)
    private static func fetchTransactions(after token: DefaultHistoryToken?) throws -> [DefaultHistoryTransaction] {
        var historyDescriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        if let token {
            historyDescriptor.predicate = #Predicate { transaction in
                (transaction.token > token)
            }
        }

        return try DataProvider.newContext().fetchHistory(historyDescriptor)
    }

    @available(iOS 18.0, *)
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
        if #available(iOS 18, *) {
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
        // history api unavailable, always assume there are changes
        return nil
    }
}
