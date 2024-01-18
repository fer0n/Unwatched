//
//  VideoError.swift
//  Unwatched
//

import Foundation

enum VideoError: LocalizedError {
    case noVideoFound

    var errorDescription: String? {
        switch self {
        case .noVideoFound:
            return NSLocalizedString("noVideoFound", comment: "No Supported Error")
        }
    }
}
