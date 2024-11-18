//
//  TransactionVM.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared
import SwiftUI
import OSLog

@Observable class TransactionVM<T: PersistentModel> {
    @ObservationIgnored
    @available(iOS 18.0, *)
    var historyToken: DefaultHistoryToken? {
        get {
            localhistoryToken as? DefaultHistoryToken
        }
        set {
            localhistoryToken = newValue
        }
    }
    private var localhistoryToken: Any?

    @available(iOS 18, *)
    static func findTransactions(after token: DefaultHistoryToken?) -> [DefaultHistoryTransaction] {
        var historyDescriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        if let token {
            historyDescriptor.predicate = #Predicate { transaction in
                (transaction.token > token)
            }
        }

        var transactions: [DefaultHistoryTransaction] = []
        let taskContext = DataProvider.newContext()
        do {
            transactions = try taskContext.fetchHistory(historyDescriptor)
        } catch let error {
            print(error)
        }

        return transactions
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
                var newToken: DefaultHistoryToken?
                var modelUpdates: Set<PersistentIdentifier>?

                let transactions = TransactionVM.findTransactions(after: token)
                if let last = transactions.last?.token {
                    newToken = last
                }
                Logger.log.info("modelsHaveChanges: \(transactions.count)")
                if transactions.count <= 20 {
                    // if there's more than 20 changes, simply fetch everything
                    modelUpdates = TransactionVM.getModelUpdates(transactions)
                }
                return (newToken, modelUpdates)
            }
            let (newToken, modelUpdates) = await task.value
            historyToken = newToken
            return modelUpdates
        }
        // history api unavailable, always assume there are changes
        return nil
    }
}
