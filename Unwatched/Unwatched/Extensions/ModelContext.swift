//
//  ModelContext.swift
//  Unwatched
//

import SwiftData
import SwiftUI

extension ModelContext {
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
}
