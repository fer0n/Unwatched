//
//  DescriptionButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DescriptionButton: View {
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @Environment(\.colorScheme) var colorScheme
    @Binding var show: Bool

    private let shortcut = KeyboardShortcut("i", modifiers: [])

    var body: some View {
        Button {
            show.toggle()
        } label: {
            Image(Const.videoDescriptionSF)
                .symbolRenderingMode(.monochrome)
                .playerToggleModifier(isOn: show, isSmall: true)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $show) {
            if let video = player.video {
                ChapterDescriptionView(
                    video: video,
                    scrollToCurrent: true,
                    showThumbnail: false,
                    showActions: false
                )
                .presentationBackground(.black)
                .environment(\.colorScheme, colorScheme)
                .environment(player)
                .environment(navManager)
                .frame(idealWidth: 500, maxWidth: 500, maxHeight: 600)
            }
        }
        .keyboardShortcut(shortcut)
        .help(String(localized: "videoDescription"), shortcut: shortcut)
        .sensoryFeedback(Const.sensoryFeedback, trigger: show)
    }
}
