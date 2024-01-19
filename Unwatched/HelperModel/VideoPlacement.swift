//
//  VideoPlacement.swift
//  Unwatched
//

import Foundation

enum VideoPlacement: Int, Codable, CaseIterable {
    case inbox
    case queue
    case nothing
    case defaultPlacement

    func description(defaultPlacement: String) -> String {
        switch self {
        case .inbox: return String(localized: "addToInbox")
        case .queue: return String(localized: "addToQueue")
        case .nothing: return String(localized: "doNothing")
        case .defaultPlacement: return String(localized: "useDefault") + " (\(defaultPlacement))"
        }
    }
}

struct DefaultVideoPlacement {
    var videoPlacement: VideoPlacement
    var shortsPlacement: VideoPlacement?
    var shortsDetection: ShortsDetection = .safe
}
