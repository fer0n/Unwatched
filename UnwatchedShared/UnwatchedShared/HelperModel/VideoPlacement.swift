//
//  VideoPlacement.swift
//  Unwatched
//

import Foundation

public enum VideoPlacementArea: Sendable {
    case inbox
    case queue
}

public enum VideoPlacement: Int, Codable, CaseIterable, Sendable {
    case inbox = 0
    case queueNext = 1
    case queueLast = 4
    case nothing = 2
    case defaultPlacement = 3

    public static func isQueue(_ placement: VideoPlacement?) -> Bool {
        placement == .queueLast || placement == .queueNext
    }

    public var resolvedPlacement: VideoPlacement {
        if self == .defaultPlacement {
            let videoPlacementRaw = UserDefaults.standard.integer(forKey: Const.defaultVideoPlacement)
            return VideoPlacement(rawValue: videoPlacementRaw) ?? .inbox
        }
        return self
    }
}

public struct DefaultVideoPlacement {
    public init(videoPlacement: VideoPlacement, hideShorts: Bool, filterVideoTitleText: String) {
        self.videoPlacement = videoPlacement
        self.hideShorts = hideShorts
        self.filterVideoTitleText = filterVideoTitleText
    }

    public var videoPlacement: VideoPlacement
    public var hideShorts: Bool
    public var filterVideoTitleText: String
}
