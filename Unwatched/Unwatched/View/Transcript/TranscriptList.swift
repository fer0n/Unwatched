//
//  TranscriptList.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TranscriptList: View {
    @Environment(PlayerManager.self) var player
    let transcript: [TranscriptEntry]
    let isCurrentVideo: Bool

    var body: some View {
        ForEach(transcript) { entry in
            TranscriptRow(
                entry: entry,
                isActive: isEntryActive(entry),
                onTap: { handleTap(entry) }
            )
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

struct TranscriptRow: View {
    let entry: TranscriptEntry
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Text(entry.text)
            .opacity(isActive ? 1 : 0.5)
            .padding(.vertical, 4)
            .onTapGesture(perform: onTap)
            .padding(.bottom, entry.isParagraphEnd ? 20 : 0)
    }
}
