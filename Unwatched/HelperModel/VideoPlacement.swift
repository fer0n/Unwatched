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
        case .defaultPlacement: return String(localized: "defaultVideoPlacement \(defaultPlacement)")
        }
    }

    var description: String {
        switch self {
        case .inbox: return String(localized: "addToInbox")
        case .queue: return String(localized: "addToQueue")
        case .nothing: return String(localized: "doNothing")
        case .defaultPlacement: return String(localized: "useDefault")
        }
    }

    var shortDescription: String {
        switch self {
        case .inbox: return String(localized: "addToInboxShort")
        case .queue: return String(localized: "addToQueueShort")
        case .nothing: return String(localized: "doNothingShort")
        case .defaultPlacement: return String(localized: "useDefault")
        }
    }

    var systemName: String? {
        switch self {
        case .inbox: return Const.inboxTabEmptySF
        case .queue: return Const.queueTagSF
        case .nothing: return Const.clearSF
        case .defaultPlacement: return nil
        }
    }
}

struct DefaultVideoPlacement {
    var videoPlacement: VideoPlacement
    var hideShortsEverywhere: Bool
}
