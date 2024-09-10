//
//  ModelContainer.swift
//  Unwatched
//

import SwiftData

/// Automatically saves the context when done
extension ModelContainer {
    func useContext(perform: (ModelContext) -> Void) {
        let context = ModelContext(self)
        perform(context)

        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}
