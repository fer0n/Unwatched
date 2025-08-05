//
//  VideoChangeReason.swift
//  Unwatched
//

enum VideoChangeReason: Sendable {
    case clearAbove,
         clearBelow,
         moveToQueue,
         moveToInbox,
         toggleWatched,
         clearEverywhere
}
