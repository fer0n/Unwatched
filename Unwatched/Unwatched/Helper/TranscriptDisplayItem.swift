//
//  TranscriptDisplayItem.swift
//  Unwatched
//

import UnwatchedShared
import SwiftUI

enum TranscriptDisplayItem: Identifiable {
    case entry(TranscriptEntry, isMatch: Bool)
    case separator(UUID)
    /// Audio the published transcript doesn't cover. What's in it is deliberately not claimed.
    case gap(TranscriptAlignment.Gap, id: UUID)

    var id: UUID {
        switch self {
        case .entry(let entry, _):
            return entry.id
        case .separator(let id):
            return id
        case .gap(_, let id):
            return id
        }
    }
}
