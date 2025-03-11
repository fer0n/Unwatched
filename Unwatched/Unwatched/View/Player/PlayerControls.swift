//
//  PlayerControls.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerControls: View {
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide

    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager

    @ScaledMetric var speedSpacingScaled = 8

    let compactSize: Bool
    let showInfo: Bool
    let horizontalLayout: Bool
    let enableHideControls: Bool
    let hideControls: Bool

    let setShowMenu: () -> Void
    let markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var sleepTimerVM: SleepTimerViewModel

    @Binding var minHeight: CGFloat?
    @State var autoHideVM = AutoHideVM()
    @State var showDescriptionPopover: Bool = false

    var speedSpacing: CGFloat {
        speedSpacingScaled + (showRotateFullscreen || compactSize ? -2 : 2)
    }

    var showRotateFullscreen: Bool {
        fullscreenControlsSetting != .disabled
            && !Device.requiresFullscreenWebWorkaround
            && !compactSize
    }

    var body: some View {
        let layout = compactSize
            ? AnyLayout(HStackLayout(spacing: 20))
            : AnyLayout(VStackLayout(spacing: player.isCompactHeight ? 15 : 25))

        let outerLayout = horizontalLayout
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: 0))

        ZStack {
            outerLayout {
                if showRotateFullscreen && !player.embeddingDisabled && !player.isCompactHeight {
                    HStack(alignment: .center, spacing: 0) {
                        InteractiveSubscriptionTitle(
                            video: player.video,
                            subscription: player.video?.subscription,
                            setShowMenu: setShowMenu,
                            showImage: true
                        )
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .foregroundStyle(.secondary)

                        CoreRotateOrientationButton { image in
                            image
                                .font(.system(size: 18, weight: .medium))
                                .padding()
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
                            showTemporarySpeed: compactSize,
                            indicatorSpacing: player.embeddingDisabled
                                ? 2
                                : compactSize
                                ? 2.5
                                : 4
                        )
                        .fixedSize(horizontal: compactSize, vertical: false)

                        if !Device.isMac {
                            PipButton()
                        }

                        #if os(iOS)
                        AirPlayButton()
                        #endif

                        if compactSize {
                            DescriptionButton(show: $showDescriptionPopover)
                        }

                        PlayerMoreMenuButton(
                            sleepTimerVM: sleepTimerVM,
                            markVideoWatched: markVideoWatched
                        ) { image in
                            image
                                .playerToggleModifier(
                                    isOn: sleepTimerVM.isOn,
                                    isSmall: true
                                )
                                .fontWeight(.bold)
                        }

                        if showRotateFullscreen && player.embeddingDisabled {
                            RotateOrientationButton()
                        }
                    }

                    HStack {
                        WatchedButton(
                            markVideoWatched: markVideoWatched,
                            indicateWatched: false
                        )
                        .frame(maxWidth: compactSize ? nil : .infinity)

                        PlayButton(size:
                                    (player.embeddingDisabled || compactSize)
                                    ? 80
                                    : 90
                        )
                        .fontWeight(.black)

                        NextVideoButton(markVideoWatched: markVideoWatched)
                            .frame(maxWidth: compactSize ? nil : .infinity)

                        if enableHideControls {
                            HideControlsButton()
                        }
                    }
                    .padding(.horizontal, compactSize ? 0 : 10)

                    if player.isCompactHeight {
                        // make sure play button vertical spacing is equal
                        Spacer()
                            .frame(height: 0)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 20)
                .frame(maxWidth: 800)

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
            if player.isAnyCompactHeight || compactSize {
                minHeight = size.height
            }
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
        !hideControls
            || fullscreenControlsSetting != .autoHide
            || fullscreenControlsSetting == .autoHide && (!player.isPlaying || autoHideVM.showControls)
            || player.videoIsCloseToEnd
    }
}

#Preview {
    let player = PlayerManager.getDummy()
    // player.embeddingDisabled = true

    return PlayerControls(compactSize: true,
                          showInfo: false,
                          horizontalLayout: false,
                          enableHideControls: false,
                          hideControls: true,
                          setShowMenu: { },
                          markVideoWatched: { _, _ in },
                          sleepTimerVM: SleepTimerViewModel(),
                          minHeight: .constant(0))
        .modelContainer(DataProvider.previewContainer)
        .environment(player)
        .environment(SheetPositionReader())
        .environment(RefreshManager())
        .environment(NavigationManager())
        .tint(Color.neutralAccentColor)
}
