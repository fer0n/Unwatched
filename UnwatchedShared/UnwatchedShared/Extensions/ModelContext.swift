//
//  ModelContext.swift
//  Unwatched
//

import SwiftData
import SwiftUI

public extension ModelContext {
    func existingModel<T>(for objectID: PersistentIdentifier) -> T? where T: PersistentModel {
        if let registered: T = registeredModel(for: objectID) {
            return registered
        }

        let fetchDescriptor = FetchDescriptor<T>(
            predicate: #Predicate {
                $0.persistentModelID == objectID
            })

        if let model = try? fetch(fetchDescriptor).first {
            if !model.isDeleted {
                return model
            }
        }
        return nil
    }

    /// Re-resolves a model reached through a relationship, returning nil if its row is gone.
    ///
    /// A relationship can hand back an object whose row was deleted by another context. Reading any
    /// persisted property on it traps in SwiftData (`_InvalidFutureBackingData.getValue`), so
    /// anything reached that way has to be re-resolved before it's touched. Goes through a fetch
    /// rather than `registeredModel(for:)`, which returns the unusable object as-is.
    func resolvedModel<T>(_ model: T) -> T? where T: PersistentModel {
        existingModelViaFetch(for: model.persistentModelID)
    }

    private func existingModelViaFetch<T>(for objectID: PersistentIdentifier) -> T? where T: PersistentModel {
        var fetchDescriptor = FetchDescriptor<T>(
            predicate: #Predicate {
                $0.persistentModelID == objectID
            })
        fetchDescriptor.fetchLimit = 1

        guard let model = try? fetch(fetchDescriptor).first, !model.isDeleted else {
            return nil
        }
        return model
    }
}
