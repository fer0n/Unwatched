//
//  FullscreenPlayerControls.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct FullscreenPlayerControls: View {
    @Environment(PlayerManager.self) var player
    @Binding var menuOpen: Bool

    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var arrowEdge: Edge
    var sleepTimerVM: SleepTimerViewModel

    var body: some View {
        let hasChapters = player.currentChapter != nil

        VStack {
            ZStack {
                PlayerMoreMenuButton(
                    sleepTimerVM: sleepTimerVM,
                    markVideoWatched: markVideoWatched,
                    extended: true
                ) { image in
                    image
                        .modifier(PlayerControlButtonStyle(isOn: sleepTimerVM.isOn))
                        .fontWeight(.bold)
                }
            }
            .frame(maxHeight: .infinity)

            ZStack {
                if hasChapters {
                    NextChapterButton { image in
                        VStack(spacing: 5) {
                            image
                            ChapterTimeRemaining()
                        }
                        .modifier(PlayerControlButtonStyle())
                    }
                    .fontWeight(.bold)
                }
            }
            .frame(maxHeight: .infinity)
            .disabled(player.nextChapter == nil)

            ZStack {
                if hasChapters {
                    FullscreenChaptersButton(
                        arrowEdge: arrowEdge,
                        menuOpen: $menuOpen
                    )
                }
            }
            .frame(maxHeight: .infinity)

            ZStack {
                FullscreenSpeedControl(menuOpen: $menuOpen, arrowEdge: arrowEdge)
            }
            .frame(maxHeight: .infinity)

            CoreNextButton(markVideoWatched: markVideoWatched,
                           extendedContextMenu: true) { image, isOn in
                image
                    .modifier(PlayerControlButtonStyle(isOn: isOn))
            }
            .fontWeight(.bold)
            .frame(maxHeight: .infinity)

            ZStack {
                FullscreenChangeOrientationButton()
            }
            .font(.system(size: 18))
            .fontWeight(.bold)
            .frame(maxHeight: .infinity)
        }
        .environment(\.colorScheme, .dark)
        .font(.system(size: 16))
        .opacity(0.5)
        .padding(.vertical)
        .foregroundStyle(Color.neutralAccentColor)
        .frame(minWidth: 35)
    }
}

#Preview {
    HStack {
        Rectangle()
            .fill(.gray)
        FullscreenPlayerControls(
            menuOpen: .constant(false),
            markVideoWatched: { _, _ in },
            arrowEdge: .trailing,
            sleepTimerVM: SleepTimerViewModel())
            .padding()
    }
    .ignoresSafeArea(.all)
    .modelContainer(DataProvider.previewContainer)
    .environment(PlayerManager())
    .environment(NavigationManager())
}
