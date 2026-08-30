//
//  IntentError.swift
//  Unwatched
//

import Foundation

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case requiresUnwatchedPremium
    case noSegmentsFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .requiresUnwatchedPremium:
            return "requiresUnwatchedPremium"
        case .noSegmentsFound:
            return "noSegmentsFound"
        }
    }
}
