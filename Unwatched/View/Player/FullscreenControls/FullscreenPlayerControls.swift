//
//  FullscreenPlayerControls.swift
//  Unwatched
//

import SwiftUI

struct FullscreenPlayerControls: View {
    @Environment(PlayerManager.self) var player
    @State var showChapters = false
    @Binding var menuOpen: Bool

    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void

    var body: some View {
        let hasChapters = player.currentChapter != nil

        VStack {
            ZStack {
                if hasChapters {
                    Button {
                        player.goToNextChapter()
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: Const.nextChapterSF)
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
                }
            }
            .popover(isPresented: $showChapters) {
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
                        .frame(maxWidth: 350)
                    }
                    .environment(\.colorScheme, .dark)
                    .presentationCompactAdaptation(.popover)
                    .onDisappear {
                        menuOpen = false
                    }
                }
            }
            .frame(maxHeight: .infinity)

            ZStack {
                if hasChapters {
                    Button {
                        player.goToPreviousChapter()
                    } label: {
                        Image(systemName: Const.previousChapterSF)
                            .modifier(PlayerControlButtonStyle())
                    }
                    .fontWeight(.bold)
                }
            }
            .frame(maxHeight: .infinity)
            .disabled(player.previousChapterDisabled)

            ZStack {
                FullscreenSpeedControl(menuOpen: $menuOpen)
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
                Button {
                    OrientationManager.changeOrientation(to: .portrait)
                } label: {
                    Image(systemName: Const.disableFullscreenSF)
                        .modifier(PlayerControlButtonStyle())
                }
            }
            .font(.system(size: 18))
            .fontWeight(.bold)
            .frame(maxHeight: .infinity)
        }
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
            markVideoWatched: { _, _ in })
            .padding()
    }
    .ignoresSafeArea(.all)
    .modelContainer(DataController.previewContainer)
    .environment(PlayerManager())
    .environment(NavigationManager())
}
