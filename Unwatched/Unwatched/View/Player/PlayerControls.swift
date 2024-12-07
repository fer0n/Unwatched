//
//  PlayerControls.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerControls: View {
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false

    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos

    @ScaledMetric var speedSpacing = 10

    let compactSize: Bool
    let showInfo: Bool
    let horizontalLayout: Bool
    let enableHideControls: Bool

    let setShowMenu: () -> Void
    let markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var sleepTimerVM: SleepTimerViewModel

    @Binding var minHeight: CGFloat?
    @State var autoHideVM = AutoHideVM()

    var showRotateFullscreen: Bool {
        fullscreenControlsSetting != .disabled
            && !UIDevice.requiresFullscreenWebWorkaround
            && !compactSize
    }

    var body: some View {
        let layout = compactSize
            ? AnyLayout(HStackLayout(spacing: 25))
            : AnyLayout(VStackLayout(spacing: player.isCompactHeight ? 15 : 25))

        let outerLayout = horizontalLayout
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: player.isCompactHeight ? 7 : 10))

        ZStack {
            outerLayout {
                VStack(spacing: 0) {
                    if showInfo && !compactSize {
                        DescriptionMiniProgressBar()
                            .padding(.horizontal, 2)
                            .padding(10)
                    }

                    if showRotateFullscreen && !player.embeddingDisabled && !player.isCompactHeight {
                        RotateOrientationButton()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing)
                    }
                }

                if !player.embeddingDisabled && !compactSize && !player.isCompactHeight {
                    Spacer()
                }

                ChapterMiniControlView(setShowMenu: setShowMenu)
                    .padding(.horizontal)

                if !player.embeddingDisabled && !compactSize && !player.isCompactHeight {
                    Spacer()
                    Spacer()
                }

                layout {
                    HStack(spacing: speedSpacing) {
                        CombinedPlaybackSpeedSetting(
                            spacing: speedSpacing,
                            showTemporarySpeed: compactSize
                        )

                        if !UIDevice.isMac {
                            PipButton()
                        }

                        PlayerMoreMenuButton(
                            sleepTimerVM: sleepTimerVM,
                            markVideoWatched: markVideoWatched
                        ) { image in
                            image
                                .playerToggleModifier(isOn: sleepTimerVM.isOn, isSmall: true)
                                .fontWeight(.bold)
                        }

                        if showRotateFullscreen && player.embeddingDisabled {
                            RotateOrientationButton()
                        }
                    }

                    HStack {
                        WatchedButton(markVideoWatched: markVideoWatched)
                            .frame(maxWidth: .infinity)

                        PlayButton(size:
                                    (player.embeddingDisabled || compactSize)
                                    ? 70
                                    : 90
                        )
                        .fontWeight(.black)

                        NextVideoButton(markVideoWatched: markVideoWatched)
                            .frame(maxWidth: .infinity)

                        if enableHideControls {
                            HideControlsButton()
                        }
                    }
                    .padding(.horizontal, 10)

                    if player.isCompactHeight {
                        // make sure play button vertical spacing is equal
                        Spacer()
                            .frame(height: 0)
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: 1000)

                if !player.embeddingDisabled && !compactSize && !player.isCompactHeight {
                    Spacer()
                    Spacer()
                }
                if !compactSize {
                    Button {
                        setShowMenu()
                    } label: {
                        VStack {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 30))
                                .fontWeight(.regular)
                            Text("showMenu")
                                .font(.caption)
                                .textCase(.uppercase)
                                .padding(.bottom, 3)
                                .fixedSize()
                                .fontWeight(.bold)
                        }
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.automaticBlack.opacity(0.5))
                    .padding(8)
                }
            }
            .opacity(showControls ? 1 : 0)
        }
        .padding(.bottom, 5)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onSizeChange { size in
            sheetPos.setPlayerControlHeight(size.height - Const.playerControlPadding)
            if player.isAnyCompactHeight || compactSize {
                minHeight = size.height
            }
        }
        .animation(.default.speed(3), value: showControls)
        .animation(.default, value: player.isCompactHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            if !showControls {
                autoHideVM.setShowControls()
            }
        }
        .onHover { over in
            autoHideVM.setKeepVisible(over, "hover")
        }
    }

    func onSleepTimerEnded(_ fadeOutSeconds: Double?) {
        var seconds = player.currentTime ?? 0
        player.pause()
        if let fadeOutSeconds = fadeOutSeconds, fadeOutSeconds > seconds {
            seconds -= fadeOutSeconds
        }
        player.updateElapsedTime(seconds)
    }

    var showControls: Bool {
        !hideControlsFullscreen
            || fullscreenControlsSetting != .autoHide
            || fullscreenControlsSetting == .autoHide && (!player.isPlaying || autoHideVM.showControls)
            || player.videoIsCloseToEnd
    }
}

#Preview {
    let player = PlayerManager.getDummy()
    // player.embeddingDisabled = true

    return PlayerControls(compactSize: false,
                          showInfo: false,
                          horizontalLayout: false,
                          enableHideControls: false,
                          setShowMenu: { },
                          markVideoWatched: { _, _ in },
                          sleepTimerVM: SleepTimerViewModel(),
                          minHeight: .constant(0))
        .modelContainer(DataProvider.previewContainer)
        .environment(player)
        .environment(SheetPositionReader())
        .environment(RefreshManager())
        .tint(Color.neutralAccentColor)
}
