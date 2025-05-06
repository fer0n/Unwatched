//
//  FullscreenChaptersButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct FullscreenChaptersButton: View {
    @Environment(PlayerManager.self) var player
    @State var show = false

    var arrowEdge: Edge
    @Binding var menuOpen: Bool
    var size: CGFloat

    var body: some View {
        Button {
            if !show {
                show = true
                menuOpen = true
            }
        } label: {
            Image(Const.videoDescriptionCircleSF)
                .resizable()
                .modifier(PlayerControlButtonStyle())
                .frame(width: size, height: size)
        }
        .fontWeight(.bold)
        .accessibilityLabel("videoDescription")
        .padding(.horizontal) // workaround: safearea pushing content in pop over
        .popover(isPresented: $show, arrowEdge: arrowEdge) {
            if let video = player.video {
                ZStack {
                    Color.sheetBackground
                        .scaleEffect(1.5)

                    ChapterDescriptionView(video: video, isCompact: true, scrollToCurrent: true)
                        .scrollIndicators(.hidden)
                        .frame(
                            minWidth: 200,
                            idealWidth: 350,
                            maxWidth: 350
                        )
                }
                .environment(\.colorScheme, .dark)
                .presentationCompactAdaptation(.popover)
                .onDisappear {
                    menuOpen = false
                }
                .fontWeight(nil)
            }
        }
    }
}

#Preview {
    FullscreenChaptersButton(
        arrowEdge: .bottom,
        menuOpen: .constant(true),
        size: 40
    )
    .environment(PlayerManager())
}
