//
//  FullscreenChaptersButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct FullscreenChaptersButton: View {
    @Environment(PlayerManager.self) var player
    @State var showChapters = false

    var arrowEdge: Edge

    @Binding var menuOpen: Bool

    var body: some View {
        Button {
            if !showChapters {
                showChapters = true
                menuOpen = true
            }
        } label: {
            Image(systemName: Const.chaptersSF)
                .modifier(PlayerControlButtonStyle())
        }
        .fontWeight(.bold)
        .accessibilityLabel("chapters")
        .popover(isPresented: $showChapters, arrowEdge: arrowEdge) {
            if let video = player.video {
                ZStack {
                    Color.sheetBackground
                        .scaleEffect(1.5)

                    ScrollViewReader { proxy in
                        ScrollView {
                            ChapterList(video: video, isCompact: true)
                                .padding(6)
                        }
                        .onAppear {
                            proxy.scrollTo(player.currentChapter?.persistentModelID, anchor: .center)
                        }
                        .scrollIndicators(.hidden)
                    }
                    .frame(minWidth: 200, maxWidth: 350)
                }
                .environment(\.colorScheme, .dark)
                .presentationCompactAdaptation(.popover)
                .onDisappear {
                    menuOpen = false
                }
            }
        }
    }
}
