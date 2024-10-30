//
//  TransactionVM.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared
import SwiftUI
import OSLog

@Observable class TransactionVM<T: PersistentModel> {
    var container: ModelContainer?

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
    func findTransactions(after token: DefaultHistoryToken?) -> [DefaultHistoryTransaction] {
        guard let container = container else {
            Logger.log.warning("findTransactions: no container")
            return []
        }

        var historyDescriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        if let token {
            historyDescriptor.predicate = #Predicate { transaction in
                (transaction.token > token)
            }
        }

        var transactions: [DefaultHistoryTransaction] = []
        let taskContext = ModelContext(container)
        do {
            transactions = try taskContext.fetchHistory(historyDescriptor)
        } catch let error {
            print(error)
        }

        return transactions
    }

    @available(iOS 18.0, *)
    func getModelUpdates(_ transactions: [DefaultHistoryTransaction]) -> Set<PersistentIdentifier>? {
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

    func modelsHaveChangesUpdateToken() -> Set<PersistentIdentifier>? {
        if #available(iOS 18, *) {
            let transactions = findTransactions(after: historyToken)
            if let last = transactions.last?.token {
                historyToken = last
            }
            Logger.log.info("modelsHaveChanges: \(transactions.count)")
            if transactions.count <= 20 {
                // if there's more than 20 changes, simply fetch everything
                return getModelUpdates(transactions)
            }
        }
        // history api unavailable, always assume there are changes
        return nil
    }
}
