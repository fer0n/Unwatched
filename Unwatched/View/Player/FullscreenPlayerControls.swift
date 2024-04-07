//
//  FullscreenPlayerControls.swift
//  Unwatched
//

import SwiftUI

struct FullscreenPlayerControls: View {
    @Environment(PlayerManager.self) var player
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0

    @State var showChapters = false
    @State var showSpeedControl = false

    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void

    var body: some View {
        let hasChapters = player.currentChapter != nil
        @Bindable var player = player

        VStack {
            ZStack {
                if hasChapters {
                    Button {
                        player.goToNextChapter()
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: Const.nextChapterSF)
                            if let remaining = currentRemaining {
                                Text(remaining)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                    .opacity(0.8)
                            }
                        }
                        .modifier(PlayerControlButtonStyle())
                    }
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
                }
            }
            .frame(maxHeight: .infinity)
            .disabled(player.previousChapter == nil)

            let customSetting = player.video?.subscription?.customSpeedSetting != nil
            ZStack {
                Button {
                    showSpeedControl = true
                } label: {
                    HStack(spacing: 0) {
                        Text(verbatim: SpeedControlViewModel.formatSpeed(player.playbackSpeed))
                            .font(.custom("SFCompactDisplay-Semibold", size: 16))
                        Text(verbatim: "×")
                            .font(.custom("SFCompactDisplay-Semibold", size: 12))
                    }
                    .fixedSize()
                    .modifier(PlayerControlButtonStyle(isOn: customSetting))
                    .animation(.default, value: customSetting)
                }
                .frame(width: 35)
            }
            .popover(isPresented: $showSpeedControl) {
                ZStack {
                    Color.sheetBackground
                        .scaleEffect(1.5)

                    HStack {
                        SpeedControlView(selectedSpeed: $player.playbackSpeed)
                        CustomSettingsButton(playbackSpeed: $playbackSpeed)
                    }
                    .padding(.horizontal)
                    .frame(width: 350)
                }
                .environment(\.colorScheme, .dark)
                .presentationCompactAdaptation(.popover)
            }
            .frame(maxHeight: .infinity)

            CoreNextButton(markVideoWatched: markVideoWatched) { image, isOn in
                image
                    .modifier(PlayerControlButtonStyle(isOn: isOn))
            }
            .frame(maxHeight: .infinity)

            CorePlayButton(circleVariant: false) { image in
                image
                    .modifier(PlayerControlButtonStyle())
                    .font(.system(size: 25))
            }
            .frame(maxHeight: .infinity)
        }
        .font(.system(size: 16))
        .opacity(0.6)
        .padding(.vertical)
        .foregroundStyle(Color.neutralAccentColor)
    }

    var currentRemaining: String? {
        player.currentRemaining?.formatTimeMinimal

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

struct PlayerControlButtonStyle: ViewModifier {
    @Environment(\.isEnabled) var isEnabled
    var isOn: Bool = false

    func body(content: Content) -> some View {

        VStack(spacing: 5) {
            content
            if isOn {
                Circle()
                    .frame(width: 5, height: 5)
            }
        }
        .opacity(isEnabled ? 1 : 0.3)
        .padding(10)
    }
}
