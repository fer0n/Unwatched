//
//  TranscriptDisplayItem.swift
//  Unwatched
//

import UnwatchedShared
import SwiftUI

enum TranscriptDisplayItem: Identifiable {
    case entry(TranscriptEntry, isMatch: Bool)
    case separator(UUID)

    var id: UUID {
        switch self {
        case .entry(let entry, _):
            return entry.id
        case .separator(let id):
            return id
        }
    }
}
