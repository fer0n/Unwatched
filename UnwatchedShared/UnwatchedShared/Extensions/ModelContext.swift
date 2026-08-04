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

    /// Re-resolves a model reached through a relationship, returning nil if its row was deleted.
    func resolvedModel<T>(_ model: T) -> T? where T: PersistentModel {
        resolvedModel(withID: model.persistentModelID)
    }

    /// Looks a model up by id, returning nil if its row is gone.
    ///
    /// Use this to pick models back up after an `await`, where the id is what should have crossed
    /// the suspension rather than the model. Unlike `existingModel(for:)` it never goes through
    /// `registeredModel(for:)`, which hands back an object whose row another context deleted —
    /// reading any property on that traps.
    func resolvedModel<T>(withID objectID: PersistentIdentifier) -> T? where T: PersistentModel {
        existingModelViaFetch(for: objectID)
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
