//
//  ShortsFilter.swift
//  Unwatched
//

import Foundation

enum ShortsDetection: Int, Codable, CaseIterable {
    case safe
    case moderate

    var description: String {
        switch self {
        case .safe: return String(localized: "shortsDetectionSafe")
        case .moderate: return String(localized: "shortsDetectionModerate")
        }
    }
}
