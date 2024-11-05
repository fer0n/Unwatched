//
//  VideoError.swift
//  Unwatched
//

import Foundation
import SwiftUI

enum VideoError: Error, CustomLocalizedStringResourceConvertible {
    case noVideoFound
    case noYoutubeId
    case noYoutubePlaylistId
    case faultyYoutubeVideoId(_ youtubeId: String)
    case emptyYoutubeId
    case noVideosFoundInPlaylist
    case noVideoInfo
    case noVideoUrl

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noVideoFound:
            return "noVideoFound"
        case .noYoutubeId:
            return "noYoutubeIdFound"
        case .faultyYoutubeVideoId(let youtubeId):
            return "potentiallyFaultyYoutubeId\(youtubeId)"
        case .emptyYoutubeId:
            return "emptyYoutubeId"
        case .noYoutubePlaylistId:
            return "noYoutubePlaylistId"
        case .noVideosFoundInPlaylist:
            return "noVideosFoundInPlaylist"
        case .noVideoInfo:
            return "noVideoInfo"
        case .noVideoUrl:
            return "noVideoUrl"
        }
    }
}
