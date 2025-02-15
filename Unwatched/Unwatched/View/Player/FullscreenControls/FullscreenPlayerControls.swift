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

        VStack(spacing: 0) {
            Spacer()

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

            Spacer()
            Spacer()

            NextChapterButton(isCircleVariant: true) { image in
                VStack(spacing: 0) {
                    image
                        .resizable()
                        .frame(width: size, height: size)
                    ChapterTimeRemaining()
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foregroundGray.opacity(0.5))
                }
                .modifier(PlayerControlButtonStyle())
            }
            .opacity(hasChapters ? 1 : 0)
            .disabled(player.nextChapter == nil)

            Spacer()
            Spacer()

            ZStack {
                if hasChapters {
                    FullscreenChaptersButton(
                        arrowEdge: arrowEdge,
                        menuOpen: $menuOpen,
                        size: size
                    )
                }
            }
            .frame(minHeight: size)

            Spacer()
            Spacer()

            FullscreenSpeedControl(
                menuOpen: $menuOpen,
                arrowEdge: arrowEdge,
                size: size
            )

            Spacer()
            Spacer()

            CoreNextButton(markVideoWatched: markVideoWatched,
                           extendedContextMenu: true,
                           isCircleVariant: true) { image, isOn in
                image
                    .resizable()
                    .frame(width: size, height: size)
                    .modifier(PlayerControlButtonStyle(isOn: isOn))
            }

            Spacer()
            Spacer()

            FullscreenChangeOrientationButton(size: size)

            Spacer()
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
