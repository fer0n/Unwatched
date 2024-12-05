//
//  VideoPlacement.swift
//  Unwatched
//

import Foundation

public enum VideoPlacementArea {
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
}

public struct DefaultVideoPlacement {
    public init(videoPlacement: VideoPlacement, hideShorts: Bool) {
        self.videoPlacement = videoPlacement
        self.hideShorts = hideShorts
    }

    public var videoPlacement: VideoPlacement
    public var hideShorts: Bool
}
