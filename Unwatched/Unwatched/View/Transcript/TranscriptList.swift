//
//  TranscriptList.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TranscriptList: View {
    @Environment(PlayerManager.self) var player
    let transcript: [TranscriptDisplayItem]
    let isCurrentVideo: Bool
    let isSearching: Bool

    var body: some View {
        // Each element is a single concrete view type so the lazy layout
        // doesn't have to project `_ConditionalContent` for every entry when
        // walking the list (e.g. during `scrollTo`), which caused hangs on
        // long transcripts.
        ForEach(transcript) { item in
            TranscriptItemRow(
                item: item,
                isActive: isActive(item),
                isSearching: isSearching,
                onTap: handleTap
            )
        }
    }

    var time: Double {
        (player.currentTime ?? 0) + 1
    }

    private func isActive(_ item: TranscriptDisplayItem) -> Bool {
        guard case .entry(let entry, _) = item else { return false }
        if !isCurrentVideo {
            return true
        }
        return entry.start < time && (entry.start + entry.duration) >= time
    }

    func handleTap(_ entry: TranscriptEntry) {
        guard isCurrentVideo else {
            return
        }
        player.currentTime = entry.start
        player.seek(to: entry.start)
        player.play()
    }
}

struct TranscriptItemRow: View {
    let item: TranscriptDisplayItem
    let isActive: Bool
    let isSearching: Bool
    let onTap: (TranscriptEntry) -> Void

    var body: some View {
        switch item {
        case .entry(let entry, let isMatch):
            TranscriptRow(
                entry: entry,
                isActive: isActive,
                isMatch: isMatch,
                isSearching: isSearching,
                onTap: { onTap(entry) }
            )
        case .separator:
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
    }
}
