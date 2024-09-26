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
    public init(videoPlacement: VideoPlacement, shortsPlacement: ShortsPlacement) {
        self.videoPlacement = videoPlacement
        self.shortsPlacement = shortsPlacement
    }

    public var videoPlacement: VideoPlacement
    public var shortsPlacement: ShortsPlacement
}
