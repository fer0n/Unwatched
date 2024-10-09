//
//  VideoError.swift
//  Unwatched
//

import Foundation
import SwiftUI

enum VideoError: LocalizedError {
    case noVideoFound
    case noYoutubeId
    case noYoutubePlaylistId
    case faultyYoutubeVideoId(_ youtubeId: String)
    case emptyYoutubeId
    case noVideosFoundInPlaylist
    case noVideoInfo

    var errorDescription: String? {
        switch self {
        case .noVideoFound:
            return String(localized: "noVideoFound")
        case .noYoutubeId:
            return String(localized: "noYoutubeIdFound")
        case .faultyYoutubeVideoId(let youtubeId):
            return String(localized: "potentiallyFaultyYoutubeId\(youtubeId)")
        case .emptyYoutubeId:
            return String(localized: "emptyYoutubeId")
        case .noYoutubePlaylistId:
            return String(localized: "noYoutubePlaylistId")
        case .noVideosFoundInPlaylist:
            return String(localized: "noVideosFoundInPlaylist")
        case .noVideoInfo:
            return String(localized: "noVideoInfo")
        }
    }
}
