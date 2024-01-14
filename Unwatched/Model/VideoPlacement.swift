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
        case .inbox: return String(localized: "Add to inbox")
        case .queue: return String(localized: "Add to Queue")
        case .nothing: return String(localized: "Do nothing")
        case .defaultPlacement: return String(localized: "Use Default (\(defaultPlacement))")
        }
    }
}
