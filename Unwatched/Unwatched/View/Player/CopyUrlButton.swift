//
//  CopyUrlButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Takes the PiP button's spot for audio episodes, where PiP has no picture to show.
struct CopyUrlButton: View {
    @Environment(PlayerManager.self) var player

    @State var copied = false

    var body: some View {
        Button(action: copy) {
            Image(systemName: copied ? "checkmark" : Const.shareSF)
                .contentTransition(.symbolEffect(.replace))
                .playerToggleModifier(isOn: false, isSmall: true)
        }
        .buttonStyle(.plain)
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(s: 1)
            withAnimation {
                copied = false
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: copied) { _, isCopied in
            isCopied
        }
        .help("copyUrl")
        .accessibilityLabel(String(localized: "copyUrl"))
    }

    func copy() {
        guard let video = player.video, let url = UrlService.getShareUrl(video) else { return }
        ClipboardService.set(url)
        Signal.interaction("Player.CopyUrl")
        withAnimation {
            copied = true
        }
    }
}
