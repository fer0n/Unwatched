//
//  FullscreenPlayerControls.swift
//  Unwatched
//

import SwiftUI

struct FullscreenPlayerControls: View {
    @Environment(PlayerManager.self) var player
    @State var showChapters = false

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
                        showChapters = true
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
            .disabled(player.previousChapter == nil)

            ZStack {
                Button {
                    OrientationManager.changeOrientation(to: .portrait)
                } label: {
                    Image(systemName: "rotate.left.fill")
                        .modifier(PlayerControlButtonStyle())
                }
            }
            .font(.system(size: 18))
            .fontWeight(.bold)
            .frame(maxHeight: .infinity)

            ZStack {
                FullscreenSpeedControl()
            }
            .frame(maxHeight: .infinity)

            CoreNextButton(markVideoWatched: markVideoWatched) { image, isOn in
                image
                    .modifier(PlayerControlButtonStyle(isOn: isOn))
            }
            .fontWeight(.bold)
            .frame(maxHeight: .infinity)

            CorePlayButton(circleVariant: false) { image in
                image
                    .modifier(PlayerControlButtonStyle())
                    .font(.system(size: 22))
            }
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
        FullscreenPlayerControls(markVideoWatched: { _, _ in })
            .padding()
    }
    .ignoresSafeArea(.all)
    .modelContainer(DataController.previewContainer)
    .environment(PlayerManager())
    .environment(NavigationManager())
}
