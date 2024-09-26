//
//  Binding.swift
//  Unwatched
//

import Foundation
import SwiftUI

extension Binding {
    func onUpdate(_ closure: @escaping @Sendable (Value) -> Void) -> Binding<Value> {
        Binding(get: {
            wrappedValue
        }, set: { newValue in
            closure(newValue)
            wrappedValue = newValue
        })
    }
}
