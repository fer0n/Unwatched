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
    public init(
        videoPlacement: VideoPlacement,
        hideShorts: Bool,
        hideLiveStreams: Bool = false,
        filterVideoTitleText: String,
        allowOnMatch: Bool
    ) {
        self.videoPlacement = videoPlacement
        self.hideShorts = hideShorts
        self.hideLiveStreams = hideLiveStreams
        self.filterVideoTitleText = filterVideoTitleText
        self.allowOnMatch = allowOnMatch
    }

    public var videoPlacement: VideoPlacement
    public var hideShorts: Bool
    public var hideLiveStreams: Bool
    public var filterVideoTitleText: String
    public var allowOnMatch: Bool
}
