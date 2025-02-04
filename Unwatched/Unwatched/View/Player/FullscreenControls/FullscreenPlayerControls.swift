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
        let size: CGFloat = 32

        VStack {
            ZStack {
                PlayerMoreMenuButton(
                    sleepTimerVM: sleepTimerVM,
                    markVideoWatched: markVideoWatched,
                    extended: true,
                    isCircleVariant: true
                ) { image in
                    image
                        .resizable()
                        .frame(width: size, height: size)
                        .modifier(PlayerControlButtonStyle(isOn: sleepTimerVM.isOn))
                }
            }
            .frame(maxHeight: .infinity)

            ZStack {
                if hasChapters {
                    NextChapterButton(isCircleVariant: true) { image in
                        VStack(spacing: -1) {
                            image
                                .resizable()
                                .frame(width: size, height: size)
                            ChapterTimeRemaining()
                        }
                        .modifier(PlayerControlButtonStyle())
                    }
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
                    .frame(width: size, height: size)
                }
            }
            .frame(maxHeight: .infinity)

            ZStack {
                FullscreenSpeedControl(
                    menuOpen: $menuOpen,
                    arrowEdge: arrowEdge,
                    size: size
                )
            }
            .frame(maxHeight: .infinity)

            CoreNextButton(markVideoWatched: markVideoWatched,
                           extendedContextMenu: true,
                           isCircleVariant: true) { image, isOn in
                image
                    .resizable()
                    .frame(width: size, height: size)
                    .modifier(PlayerControlButtonStyle(isOn: isOn))
            }
            .frame(maxHeight: .infinity)

            ZStack {
                FullscreenChangeOrientationButton(size: size)
            }
            .frame(maxHeight: .infinity)
        }
        .foregroundStyle(Color.neutralAccentColor)
        .fontWeight(.bold)
        .environment(\.colorScheme, .dark)
        .padding(.vertical)
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
