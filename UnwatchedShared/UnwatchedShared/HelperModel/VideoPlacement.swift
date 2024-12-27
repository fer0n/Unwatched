//
//  VideoPlacement.swift
//  Unwatched
//

import Foundation

public enum VideoPlacement: Int, Codable, CaseIterable {
    case inbox
    case queue
    case nothing
    case defaultPlacement
}

public struct DefaultVideoPlacement {
    public init(videoPlacement: VideoPlacement, hideShorts: Bool) {
        self.videoPlacement = videoPlacement
        self.hideShorts = hideShorts
    }

    public var videoPlacement: VideoPlacement
    public var hideShorts: Bool
}
