//
//  ChapterTimeRemaining.swift
//  Unwatched
//

import SwiftUI

struct ChapterTimeRemaining: View {
    @Environment(PlayerManager.self) var player

    var body: some View {
        if let remaining = currentRemaining {
            Text(remaining)
                .font(.system(size: 12))
                .lineLimit(1)
                .opacity(0.8)
        }
    }

    var currentRemaining: String? {
        player.currentRemaining?.formatTimeMinimal
    }
}
