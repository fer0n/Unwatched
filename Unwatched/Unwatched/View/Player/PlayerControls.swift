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

    @ScaledMetric var speedSpacingScaled = 10

    let compactSize: Bool
    let horizontalLayout: Bool
    let enableHideControls: Bool
    let hideControls: Bool

    var sleepTimerVM: SleepTimerViewModel

    @Binding var minHeight: CGFloat?
    @Binding var autoHideVM: AutoHideVM

    var speedSpacing: CGFloat {
        speedSpacingScaled + (showRotateFullscreen || compactSize ? -2 : 2)
    }

    var showRotateFullscreen: Bool {
        fullscreenControlsSetting != .disabled
            && !Device.requiresFullscreenWebWorkaround
            && !compactSize
    }

    /// The show's name and the fullscreen button above the scrubber.
    var showSubscriptionRow: Bool {
        showRotateFullscreen && !player.embeddingDisabled && !player.isAudioOnly
    }

    /// An audio episode has no video to fill the player, so its cover art takes whatever height the controls give up.
    var compressLayout: Bool {
        player.isAudioOnly && !compactSize && !horizontalLayout
    }

    @ViewBuilder
    func controlsSpacer(max maxHeight: CGFloat) -> some View {
        if compressLayout {
            // fixed, not capped: PlayerControls measures itself into this page's minHeight, so a
            // spacer that can still give under a tight proposal reopens that self-referential loop
            // and the controls jitter a few points as the sheet moves. See player-controls-minheight-layout-loop.
            Spacer()
                .frame(height: maxHeight)
        } else {
            Spacer()
        }
    }

    var body: some View {
        let layout = compactSize
            ? AnyLayout(HStackLayout(spacing: 20))
            : AnyLayout(VStackLayout(spacing: player.isTallAspectRatio ? 15 : 25))

        let outerLayout = horizontalLayout
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: 0))
        ZStack {
            outerLayout {
                if showSubscriptionRow && !player.isTallAspectRatio {
                    HStack(alignment: .center, spacing: 0) {
                        InteractiveSubscriptionTitle(
                            subscription: player.video?.subscription,
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
                        .opacity(player.video != nil ? 1 : 0)
                    }
                    .padding(.top, Const.iOS26_1 ? 7 : 0)
                    .padding(.horizontal, Const.iOS26_1 ? 5 : 0)
                }

                if showSubscriptionRow && player.isTallAspectRatio {
                    HStack(alignment: .center, spacing: 0) {
                        InteractiveSubscriptionTitle(
                            subscription: player.video?.subscription,
                            showImage: true
                        )
                        .font(.headline)
                        .fontWeight(.medium)
                        .fontWidth(.condensed)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .foregroundStyle(.secondary)

                        ToggleTallFullscreenButton { image in
                            image
                                .font(.system(size: 18, weight: .medium))
                                .padding()
                        }
                        .opacity(player.video != nil ? 1 : 0)
                    }
                    .padding(.top, Const.iOS26_1 ? 7 : 0)
                    .padding(.horizontal, Const.iOS26_1 ? 5 : 0)
                }

                if !player.embeddingDisabled && !compactSize && !player.isTallAspectRatio {
                    controlsSpacer(max: 6)
                }

                ChapterMiniControlView(
                    compactSize: compactSize,
                    autoHideVM: autoHideVM,
                    limitHeight: horizontalLayout || player.isTallAspectRatio,
                    inlineTime: horizontalLayout || player.isTallAspectRatio,
                    )
                .contentShape(Rectangle())
                .padding(.horizontal)

                if !player.embeddingDisabled && !compactSize && !player.isTallAspectRatio {
                    controlsSpacer(max: 26)
                }

                layout {
                    PlayerActionsRow(
                        maxSpacing: compactSize ? 8 : 40,
                        minSpacing: speedSpacing,
                        compactSize: compactSize,
                        showRotateButton: showRotateFullscreen && player.embeddingDisabled,
                        sleepTimerVM: sleepTimerVM,
                        autoHideVM: $autoHideVM
                    )

                    HStack(spacing: hasSmallControls ? speedSpacing : nil) {
                        SeekButton(forward: false, isSmall: hasSmallControls)
                            .frame(maxWidth: compactSize ? nil : .infinity)

                        PlayerControlsPlayButton(size: playButtonSize)
                            .frame(maxWidth: compactSize ? nil : .infinity)

                        SeekButton(forward: true, isSmall: hasSmallControls)
                            .frame(maxWidth: compactSize ? nil : .infinity)

                        if enableHideControls {
                            HideControlsButton(isSmall: true)
                        }
                    }
                    .padding(.horizontal, compactSize ? 0 : 20)
                    .frame(maxWidth: compactSize ? nil : Const.playerRowMaxWidth)

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
                    controlsSpacer(max: 16)
                }
                if !compactSize {
                    Button {
                        player.setShowMenu()
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
                    .opacity(navManager.showMenu ? 0 : 1)
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
            sheetPos.setPlayerControlHeight(size.height)
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
                          enableHideControls: false,
                          hideControls: true,
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
