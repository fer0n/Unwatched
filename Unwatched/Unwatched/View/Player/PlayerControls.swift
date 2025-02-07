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
    @Environment(NavigationManager.self) var navManager

    @ScaledMetric var speedSpacingScaled = 8

    let compactSize: Bool
    let showInfo: Bool
    let horizontalLayout: Bool
    let enableHideControls: Bool

    let setShowMenu: () -> Void
    let markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var sleepTimerVM: SleepTimerViewModel

    @State var autoHideVM = AutoHideVM()
    @State var showDescriptionPopover: Bool = false

    var speedSpacing: CGFloat {
        speedSpacingScaled + (showRotateFullscreen ? 0 : 2)
    }

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
            : AnyLayout(VStackLayout(spacing: 0))

        ZStack {
            outerLayout {
                if showRotateFullscreen && !player.embeddingDisabled && !player.isCompactHeight {
                    HStack {
                        InteractiveSubscriptionTitle(
                            video: player.video,
                            subscription: player.video?.subscription,
                            setShowMenu: setShowMenu,
                            showImage: true
                        )
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .padding(.horizontal)
                        .foregroundStyle(.secondary)

                        CoreRotateOrientationButton {
                            $0.padding()
                        }
                    }
                }

                if !player.embeddingDisabled && !compactSize && !player.isCompactHeight {
                    Spacer()
                }

                ChapterMiniControlView(setShowMenu: setShowMenu, handleTitleTap: handleTitleTap)
                    .contentShape(Rectangle())
                    .padding(.horizontal)

                if !player.embeddingDisabled && !compactSize && !player.isCompactHeight {
                    Spacer()
                }

                layout {
                    HStack(spacing: speedSpacing) {
                        CombinedPlaybackSpeedSettingPlayer(
                            spacing: speedSpacing,
                            showTemporarySpeed: compactSize
                        )

                        if !UIDevice.isMac {
                            PipButton()
                        }

                        if compactSize {
                            DescriptionButton(show: $showDescriptionPopover)
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
                .padding(.bottom, 20)
                .frame(maxWidth: 1000)

                if !player.embeddingDisabled && !compactSize && !player.isCompactHeight {
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
        .background {
            PlayerBackgroundGestureRecognizer()
        }
        .padding(.bottom, 5)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onSizeChange { size in
            sheetPos.setPlayerControlHeight(size.height - Const.playerControlPadding)
        }
        .animation(.default.speed(3), value: showControls)
        .animation(.default, value: player.isCompactHeight)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            if !showControls {
                autoHideVM.setShowControls()
            }
        })
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

    func handleTitleTap() {
        if compactSize {
            showDescriptionPopover = true
        } else {
            navManager.handleVideoDetail(scrollToCurrentChapter: true)
        }
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
                          sleepTimerVM: SleepTimerViewModel())
        .modelContainer(DataProvider.previewContainer)
        .environment(player)
        .environment(SheetPositionReader())
        .environment(RefreshManager())
        .environment(NavigationManager())
        .tint(Color.neutralAccentColor)
}
