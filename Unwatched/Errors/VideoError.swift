//
//  VideoError.swift
//  Unwatched
//

import Foundation

enum VideoError: LocalizedError {
    case noVideoFound
    case noYoutubeId

    var errorDescription: String? {
        switch self {
        case .noVideoFound:
            return NSLocalizedString("noVideoFound", comment: "")
        case .noYoutubeId:
            return NSLocalizedString("noYoutubeIdFound", comment: "")
        }
    }
}
