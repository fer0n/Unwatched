//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI
import OSLog
import SwiftData
import UnwatchedShared

struct VideoPlayer: View {
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager

    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide
    @AppStorage(Const.isFakePip) var isFakePip = false

    @State var sleepTimerVM = SleepTimerViewModel()
    @State var autoHideVM = AutoHideVM.shared

    var compactSize = false
    var horizontalLayout = false
    var limitWidth = false
    var landscapeFullscreen = true
    let hideControls: Bool

    var body: some View {
        let enableHideControls = Device.requiresFullscreenWebWorkaround && compactSize
        let padding: CGFloat = horizontalLayout ? 3 : 8

        VStack(spacing: 0) {
            #if !os(visionOS)
            if showFullscreenControlsCompactSize && !isFakePip {
                squishyPadding
                PlayButtonSpacer(
                    padding: padding * 2,
                    size: .small
                )
                .layoutPriority(1)
            }
            #endif

            PlayerView(autoHideVM: $autoHideVM,
                       landscapeFullscreen: landscapeFullscreen,
                       enableHideControls: enableHideControls,
                       sleepTimerVM: sleepTimerVM,
                       compactSize: compactSize)
                .zIndex(1)
                .layoutPriority(2)
                #if os(visionOS)
                .modifier(PlayerControlsOrnamentModifier(autoHideVM: $autoHideVM))
            #endif

            #if !os(visionOS)
            if !layoutMode.isFullscreen && !isFakePip {
                if compactSize {
                    if showFullscreenControlsCompactSize {
                        squishyPadding

                        PlayerControls(compactSize: compactSize,
                                       horizontalLayout: horizontalLayout,
                                       limitWidth: limitWidth,
                                       enableHideControls: enableHideControls,
                                       hideControls: hideControls,
                                       sleepTimerVM: sleepTimerVM,
                                       minHeight: .constant(nil),
                                       autoHideVM: $autoHideVM)
                            .padding(.vertical, padding)
                    }
                } else {
                    PlayerContentView(compactSize: compactSize,
                                      horizontalLayout: horizontalLayout,
                                      enableHideControls: enableHideControls,
                                      hideControls: hideControls,
                                      sleepTimerVM: sleepTimerVM,
                                      autoHideVM: $autoHideVM,
                                      )
                }
            }
            #endif
        }
        .appNotificationOverlay()
        .tint(.neutralAccentColor)
        .onChange(of: player.isPlaying) {
            if player.video?.isNew == true {
                player.video?.isNew = false
            }
        }
        .ignoresSafeArea(edges: layoutMode.ignoredSafeAreaEdges(embeddingDisabled: player.embeddingDisabled))
        .onChange(of: landscapeFullscreen) {
            handleFullscreenChange(.landscape, active: landscapeFullscreen)
        }
        .onChange(of: player.tallFullscreenOverlay) {
            handleFullscreenChange(.portrait, active: player.tallFullscreenOverlay)
        }
        .hideCursorOnInactive(
            after: 2,
            isEnabled: hideCursorEnabled,
            onChange: { isVisible in
                autoHideVM.setKeepVisible(isVisible, "hover")
            }
        )
    }

    var squishyPadding: some View {
        Spacer()
            .frame(minHeight: 0, maxHeight: 6)
    }

    var hideMiniPlayer: Bool {
        sheetPos.hideMiniPlayer(showMenu: navManager.showMenu, landscapeFullscreen: landscapeFullscreen)
    }

    var layoutMode: PlayerLayoutMode {
        PlayerLayoutMode(
            landscapeFullscreen: landscapeFullscreen,
            tallFullscreenOverlay: player.tallFullscreenOverlay,
            hideMiniPlayer: hideMiniPlayer
        )
    }

    enum FullscreenMode {
        case landscape, portrait
    }

    /// Keeps the menu in sync when either fullscreen mode toggles.
    /// Symmetry: entering a fullscreen mode hides the menu; exiting it restores the menu,
    /// unless the *other* fullscreen mode is still active (then the menu stays hidden).
    @MainActor
    func handleFullscreenChange(_ mode: FullscreenMode, active: Bool) {
        #if os(iOS)
        if navManager.hasSheetOpen { return }
        #endif
        if active {
            // entering fullscreen -> hide the menu
            switch mode {
            case .landscape:
                // only auto-hide when the menu sits at the player/minimum detent
                if navManager.showMenu
                    && (sheetPos.isVideoPlayer && player.isPlaying || sheetPos.isMinimumSheet) {
                    navManager.showMenu = false
                }
            case .portrait:
                // remember the menu state so it can be restored when leaving portrait fullscreen
                sheetPos.menuStateBeforeFullscreen = MenuState(
                    showMenu: navManager.showMenu,
                    detent: sheetPos.selectedDetent
                )
                navManager.showMenu = false
            }
        } else {
            // exiting -> keep the menu hidden if the other fullscreen mode is still active
            switch mode {
            case .landscape:
                if player.tallFullscreenOverlay { return }
                if navManager.showMenu {
                    // menu was open in landscape -> show it in portrait at the player detent
                    sheetPos.setDetentVideoPlayer()
                } else {
                    navManager.showMenu = true
                }
            case .portrait:
                if landscapeFullscreen { return }
                restoreMenuAfterPortraitFullscreen()
            }
        }
    }

    /// Restores the menu to the state it had before entering portrait fullscreen.
    /// Falls back to a minimized menu if no prior state was captured.
    @MainActor
    func restoreMenuAfterPortraitFullscreen() {
        if let saved = sheetPos.menuStateBeforeFullscreen {
            sheetPos.selectedDetent = saved.detent
            navManager.showMenu = saved.showMenu
        } else {
            sheetPos.setDetentMinimumSheet()
            navManager.showMenu = true
        }
        sheetPos.menuStateBeforeFullscreen = nil
    }

    var hideCursorEnabled: Bool {
        player.isPlaying
            && (
                Device.isMac && navManager.isSidebarHidden
                    || !Device.isIphone && hideControlsFullscreen
            )
            && !autoHideVM.showDescription
    }

    var showFullscreenControlsCompactSize: Bool {
        compactSize && (
            fullscreenControlsSetting != .disabled
                || Device.isMac && (!navManager.isMacosFullscreen || !horizontalLayout)
                || !Device.isMac && !horizontalLayout
        )
    }
}

#Preview {
    @Previewable @State var player = PlayerManager.getDummy()

    VideoPlayer(compactSize: false,
                horizontalLayout: false,
                limitWidth: false,
                landscapeFullscreen: false,
                hideControls: false,
                )
    .modelContainer(DataProvider.previewContainer)
    .environment(NavigationManager.getDummy(true))
    .environment(player)
    .environment(ImageCacheManager())
    .environment(RefreshManager())
    .environment(SheetPositionReader())
    .environment(TinyUndoManager())
    .tint(Color.neutralAccentColor)
    .preferredColorScheme(.dark)
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)

    //        Button {
    //            withAnimation {
    //                if player.aspectRatio ?? 1 <= 1.5 {
    //                    player.handleAspectRatio(16/9)
    //                } else {
    //                    player.handleAspectRatio(4/3)
    //                }
    //            }
    //        } label: {
    //            Text(verbatim: "switch")
    //        }
}
