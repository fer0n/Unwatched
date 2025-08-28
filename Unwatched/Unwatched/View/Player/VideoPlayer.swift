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
            if showFullscreenControlsCompactSize {
                squishyPadding
                PlayButtonSpacer(
                    padding: padding * 2,
                    size: .small
                )
                .layoutPriority(1)
            }

            PlayerView(autoHideVM: $autoHideVM,
                       landscapeFullscreen: landscapeFullscreen,
                       enableHideControls: enableHideControls,
                       sleepTimerVM: sleepTimerVM)
                .layoutPriority(2)

            if !landscapeFullscreen {
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
        }
        .tint(.neutralAccentColor)
        .onChange(of: navManager.showMenu) {
            if navManager.showMenu == false {
                sheetPos.updatePlayerControlHeight()
            }
        }
        .onChange(of: player.isPlaying) {
            if player.video?.isNew == true {
                player.video?.isNew = false
            }
        }
        .ignoresSafeArea(edges: landscapeFullscreen ? (player.embeddingDisabled ? .all : .vertical) : [])
        .onChange(of: landscapeFullscreen) {
            handleLandscapeFullscreenChange(landscapeFullscreen)
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

    @MainActor
    func handleLandscapeFullscreenChange(_ landscapeFullscreen: Bool) {
        if landscapeFullscreen && navManager.showMenu
            && (sheetPos.isVideoPlayer && player.isPlaying || sheetPos.isMinimumSheet) {
            navManager.showMenu = false
        } else if !landscapeFullscreen {
            // switching back to portrait
            if navManager.showMenu {
                // menu was open in landscape mode -> show menu in portrait
                sheetPos.setDetentVideoPlayer()
            } else {
                // show menu and keep previous detent
                navManager.showMenu = true
            }
        }
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

    GeometryReader { proxy in
        VideoPlayer(compactSize: false,
                    horizontalLayout: false,
                    limitWidth: false,
                    landscapeFullscreen: false,
                    hideControls: false,
                    //                    proxy: proxy
                    )
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.getDummy(true))
        .environment(player)
        .environment(ImageCacheManager())
        .environment(RefreshManager())
        .environment(SheetPositionReader())
        .environment(TinyUndoManager())
        .tint(Color.neutralAccentColor)
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
}
