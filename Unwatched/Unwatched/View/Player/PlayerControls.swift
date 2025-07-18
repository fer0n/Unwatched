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
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @ScaledMetric var speedSpacingScaled = 8

    let compactSize: Bool
    let horizontalLayout: Bool
    let limitWidth: Bool
    let enableHideControls: Bool
    let hideControls: Bool

    let setShowMenu: () -> Void
    let markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var sleepTimerVM: SleepTimerViewModel

    @Binding var minHeight: CGFloat?
    @Binding var autoHideVM: AutoHideVM

    var hasLargeFont: Bool {
        dynamicTypeSize > .large && !hideControlsFullscreen
    }

    var speedSpacing: CGFloat {
        speedSpacingScaled + (showRotateFullscreen || compactSize ? -2 : 2)
    }

    var showRotateFullscreen: Bool {
        fullscreenControlsSetting != .disabled
            && !Device.requiresFullscreenWebWorkaround
            && !compactSize
    }

    var body: some View {
        let layout = compactSize && !hasLargeFont
            ? AnyLayout(HStackLayout(spacing: 20))
            : AnyLayout(VStackLayout(spacing: player.isTallAspectRatio ? 15 : 25))

        let outerLayout = horizontalLayout
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: 0))

        ZStack {
            outerLayout {
                if showRotateFullscreen && !player.embeddingDisabled && !player.isTallAspectRatio {
                    HStack(alignment: .center, spacing: 0) {
                        InteractiveSubscriptionTitle(
                            subscription: player.video?.subscription,
                            setShowMenu: setShowMenu,
                            showImage: true
                        )
                        .font(.headline)
                        .fontWeight(.medium)
                        .fontWidth(.condensed)
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

                if !player.embeddingDisabled && !compactSize && !player.isTallAspectRatio {
                    Spacer()
                }

                ChapterMiniControlView(
                    setShowMenu: setShowMenu,
                    handleTitleTap: handleTitleTap,
                    limitHeight: horizontalLayout || player.isTallAspectRatio,
                    inlineTime: horizontalLayout || player.isTallAspectRatio,
                    )
                .contentShape(Rectangle())
                .padding(.horizontal)

                if !player.embeddingDisabled && !compactSize && !player.isTallAspectRatio {
                    Spacer()
                }

                layout {
                    HStack(spacing: speedSpacing) {
                        CombinedPlaybackSpeedSettingPlayer(
                            spacing: speedSpacing,
                            showTemporarySpeed: compactSize,
                            limitWidth: limitWidth,
                            indicatorSpacing: player.embeddingDisabled
                                ? 2
                                : compactSize
                                ? 2.5
                                : 2,
                            isTransparent: false
                        )
                        .fixedSize(horizontal: compactSize, vertical: false)

                        #if os(iOS)
                        PipButton()
                        AirPlayButton()
                        #endif

                        if compactSize {
                            DescriptionButton(show: $autoHideVM.showDescription)
                        }

                        if enableHideControls && hasLargeFont {
                            HideControlsButton(isSmall: true)
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

                    HStack(spacing: hasSmallControls ? speedSpacing : nil) {
                        WatchedButton(
                            markVideoWatched: markVideoWatched,
                            isSmall: hasSmallControls
                        )
                        .frame(maxWidth: compactSize ? nil : .infinity)

                        PlayerControlsPlayButton(size: playButtonSize)

                        NextVideoButton(
                            markVideoWatched: markVideoWatched,
                            isSmall: hasSmallControls
                        )
                        .frame(maxWidth: compactSize ? nil : .infinity)

                        if enableHideControls && !hasLargeFont {
                            HideControlsButton(isSmall: hasSmallControls)
                        }
                    }
                    .padding(.horizontal, compactSize ? 0 : 10)

                    if player.isTallAspectRatio {
                        // make sure play button vertical spacing is equal
                        Spacer()
                            .frame(height: 0)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, !compactSize ? 20 : 0)
                .frame(maxWidth: 800)

                if !player.embeddingDisabled && !compactSize && !player.isTallAspectRatio {
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
                    .buttonStyle(.plain)
                }
            }
            .opacity(showControls ? 1 : 0)
        }
        .background {
            PlayerBackgroundGestureRecognizer()
        }
        .padding(.bottom, compactSize ? 0 : 5 )
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onSizeChange { size in
            sheetPos.setPlayerControlHeight(size.height - Const.playerControlPadding)
            if player.limitHeight || compactSize {
                minHeight = size.height
            }
        }
        .animation(.default.speed(3), value: showControls)
        .animation(.default, value: player.isTallAspectRatio)
        .contentShape(Rectangle())
        .simultaneousGesture(
            compactSize ? DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    autoHideVM.setKeepVisible(true, "playerDrag")
                    if !showControls {
                        autoHideVM.setShowControls()
                    }
                }
                .onEnded { _ in
                    autoHideVM.setShowControls()
                    autoHideVM.setKeepVisible(false, "playerDrag")
                }
                : nil
        )
    }

    func handleTitleTap() {
        if compactSize {
            autoHideVM.showDescription = true
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

    var playButtonSize: PlayerControlsPlayButton.Size {
        horizontalLayout
            ? .small
            : player.embeddingDisabled || compactSize
            ? .medium
            : .large
    }

    var hasSmallControls: Bool {
        !player.embeddingDisabled && horizontalLayout && compactSize
    }
}

#Preview {
    let player = PlayerManager.getDummy()
    // player.embeddingDisabled = true

    return PlayerControls(compactSize: true,
                          horizontalLayout: true,
                          limitWidth: false,
                          enableHideControls: false,
                          hideControls: true,
                          setShowMenu: { },
                          markVideoWatched: { _, _ in },
                          sleepTimerVM: SleepTimerViewModel(),
                          minHeight: .constant(0),
                          autoHideVM: .constant(AutoHideVM()))
        .frame(width: 800)
        .modelContainer(DataProvider.previewContainer)
        .environment(player)
        .environment(SheetPositionReader())
        .environment(RefreshManager())
        .environment(NavigationManager())
        .tint(Color.neutralAccentColor)
}
