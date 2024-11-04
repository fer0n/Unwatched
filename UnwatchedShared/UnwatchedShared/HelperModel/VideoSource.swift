//
//  VideoSource.swift
//  Unwatched
//

public enum VideoSource: Sendable {
    case continuousPlay
    case nextUp
    case userInteraction
    case hotSwap
    case errorSwap
    case playWhenReady
}
