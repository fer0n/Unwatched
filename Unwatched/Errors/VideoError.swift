//
//  VideoError.swift
//  Unwatched
//

import Foundation

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
            return NSLocalizedString("noVideoFound", comment: "")
        case .noYoutubeId:
            return NSLocalizedString("noYoutubeIdFound", comment: "")
        case .faultyYoutubeVideoId(let youtubeId):
            return NSLocalizedString("potentiallyFaultyYoutubeId", comment: "\(youtubeId)")
        case .emptyYoutubeId:
            return NSLocalizedString("emptyYoutubeId", comment: "")
        case .noYoutubePlaylistId:
            return NSLocalizedString("noYoutubePlaylistId", comment: "")
        case .noVideosFoundInPlaylist:
            return NSLocalizedString("noVideosFoundInPlaylist", comment: "")
        case .noVideoInfo:
            return NSLocalizedString("noVideoInfo", comment: "")
        }
    }
}
