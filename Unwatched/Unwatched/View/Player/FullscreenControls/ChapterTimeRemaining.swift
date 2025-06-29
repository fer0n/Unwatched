//
//  ChapterTimeRemaining.swift
//  Unwatched
//

import SwiftUI

struct ChapterTimeRemaining: View {
    @Environment(PlayerManager.self) var player

    var body: some View {
        Text(player.currentRemainingText ?? "")
    }
}
