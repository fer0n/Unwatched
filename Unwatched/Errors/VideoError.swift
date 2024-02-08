//
//  VideoError.swift
//  Unwatched
//

import Foundation

enum VideoError: LocalizedError {
    case noVideoFound
    case noYoutubeId
    case faultyYoutubeVideoId(_ youtubeId: String)

    var errorDescription: String? {
        switch self {
        case .noVideoFound:
            return NSLocalizedString("noVideoFound", comment: "")
        case .noYoutubeId:
            return NSLocalizedString("noYoutubeIdFound", comment: "")
        case .faultyYoutubeVideoId(let youtubeId):
            return NSLocalizedString("potentiallyFaultyYoutubeId", comment: "\(youtubeId)")
        }
    }
}
