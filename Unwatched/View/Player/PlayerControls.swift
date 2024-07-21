//
//  PlayerControls.swift
//  Unwatched
//

import SwiftUI

struct PlayerControls: View {
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.showFullscreenControls) var showFullscreenControls: Bool = true

    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager
    @Environment(RefreshManager.self) var refresher
    @Environment(\.modelContext) var modelContext

    @State var sleepTimerVM = SleepTimerViewModel()
    @State var browserUrl: BrowserUrl?

    let compactSize: Bool
    let setShowMenu: () -> Void
    let showInfo: Bool
    let markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void

    var body: some View {
        let layout = compactSize
            ? AnyLayout(HStackLayout(spacing: 25))
            : AnyLayout(VStackLayout(spacing: 25))

        VStack(spacing: 10) {
            if !player.embeddingDisabled && !compactSize {
                Spacer()
            }

            ChapterMiniControlView(setShowMenu: setShowMenu, showInfo: showInfo)

            if !player.embeddingDisabled && !compactSize {
                Spacer()
                Spacer()
            }

            layout {
                if compactSize {
                    SleepTimer(viewModel: sleepTimerVM, onEnded: onSleepTimerEnded)
                }

                HStack {
                    if showFullscreenControls && UIDevice.supportsFullscreenControls {
                        RotateOrientationButton()
                    }
                    CombinedPlaybackSpeedSetting()
                }
                .environment(\.symbolVariants, .fill)

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
                }
                .padding(.horizontal, 10)
            }
            .padding(.horizontal, compactSize ? 20 : 5)

            if !player.embeddingDisabled && !compactSize {
                Spacer()
                Spacer()
            }
            if !compactSize {
                VideoPlayerFooter(openBrowserUrl: openBrowserUrl,
                                  setShowMenu: setShowMenu,
                                  sleepTimerVM: sleepTimerVM,
                                  onSleepTimerEnded: onSleepTimerEnded)
            }
        }
        .innerSizeTrackerModifier(onChange: { size in
            sheetPos.setPlayerControlHeight(size.height - Const.playerControlPadding)
        })
        .sheet(item: $browserUrl) { browserUrl in
            BrowserView(container: modelContext.container,
                        refresher: refresher,
                        startUrl: browserUrl)
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

    func openBrowserUrl(_ url: BrowserUrl) {
        let browserAsTab = UserDefaults.standard.bool(forKey: Const.browserAsTab)
        if browserAsTab {
            sheetPos.setDetentMiniPlayer()
            navManager.openUrlInApp(url)
        } else {
            browserUrl = url
        }
    }
}

#Preview {
    PlayerControls(compactSize: false,
                   setShowMenu: { },
                   showInfo: true,
                   markVideoWatched: { _, _ in })
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(PlayerManager.getDummy())
        .environment(SheetPositionReader())
        .environment(RefreshManager())
        .tint(Color.neutralAccentColor)
}
