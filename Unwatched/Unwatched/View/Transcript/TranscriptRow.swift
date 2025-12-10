//
//  TranscriptRow.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TranscriptRow: View {
    let entry: TranscriptEntry
    let isActive: Bool
    let isMatch: Bool
    let isSearching: Bool
    let onTap: () -> Void

    var body: some View {
        Text(entry.text)
            .opacity(opacity)
            .padding(.vertical, 4)
            .onTapGesture(perform: onTap)
            .padding(.bottom, entry.isParagraphEnd ? 20 : 0)
    }

    var opacity: Double {
        if isSearching {
            return isMatch ? 1.0 : 0.5
        }
        return isActive ? 1.0 : 0.5
    }
}
