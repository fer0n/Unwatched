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
