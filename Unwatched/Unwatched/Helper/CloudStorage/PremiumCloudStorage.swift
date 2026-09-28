//
//  PremiumCloudStorage.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

@propertyWrapper
@MainActor
struct PremiumCloudStorage: DynamicProperty {
    @CloudStorage private var enabled: Bool
    @CloudStorage(Const.unwatchedPremiumAcknowledged) private var premium: Bool = false

    init(wrappedValue: Bool, _ key: String) {
        _enabled = CloudStorage(wrappedValue: wrappedValue, key)
    }

    var wrappedValue: Bool {
        CloudKeyValueStore.premiumGated(enabled, premium: premium)
    }

    var projectedValue: Binding<Bool> {
        Binding(
            get: { wrappedValue },
            set: { enabled = $0 }
        )
    }
}
