//
//  IntentError.swift
//  Unwatched
//

import Foundation

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case requiresUnwatchedPremium

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .requiresUnwatchedPremium:
            return "requiresUnwatchedPremium"
        }
    }
}
