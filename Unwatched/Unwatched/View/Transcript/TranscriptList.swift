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
        ForEach(transcript) { item in
            switch item {
            case .entry(let entry, let isMatch):
                TranscriptRow(
                    entry: entry,
                    isActive: isEntryActive(entry),
                    isMatch: isMatch,
                    isSearching: isSearching,
                    onTap: { handleTap(entry) }
                )
            case .separator:
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
    }

    var time: Double {
        (player.currentTime ?? 0) + 1
    }

    private func isEntryActive(_ entry: TranscriptEntry) -> Bool {
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
