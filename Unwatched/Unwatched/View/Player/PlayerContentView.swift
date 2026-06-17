//
//  PlayerContentView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerContentView: View {
    @AppStorage(Const.hidePlayerPageIndicator) var hidePlayerPageIndicator: Bool = false

    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player

    let compactSize: Bool
    let horizontalLayout: Bool
    var limitWidth = false
    let enableHideControls: Bool
    let hideControls: Bool

    var sleepTimerVM: SleepTimerViewModel
    let fadeOutHeight: CGFloat = 25

    @State var minHeight: CGFloat?
    @Binding var autoHideVM: AutoHideVM

    var body: some View {
        @Bindable var navManager = navManager

        ZStack {
            TabView(selection: $navManager.playerTab) {
                PlayerControls(compactSize: compactSize,
                               horizontalLayout: horizontalLayout,
                               limitWidth: limitWidth,
                               enableHideControls: enableHideControls,
                               hideControls: hideControls,
                               sleepTimerVM: sleepTimerVM,
                               minHeight: $minHeight,
                               autoHideVM: $autoHideVM)
                    .padding(.vertical, compactSize ? 5 : 0)
                    .verticalSwipeGesture(
                        disableGesture: compactSize,
                        onSwipeUp: player.setShowMenu,
                        onSwipeDown: { }
                    )
                    .tabItem {
                        Image(systemName: "slider.horizontal.3")
                            .fontWeight(.black)
                        Text("controls")
                    }
                    .tag(ControlNavigationTab.controls)

                if let video = player.video {
                    ChapterDescriptionView(
                        video: video,
                        bottomSpacer: fadeOutHeight + Const.minSheetDetent,
                        showThumbnail: false,
                        showActions: false
                    )
                    .overlay {
                        PlayerTopShadow()
                    }
                    .tabItem {
                        Image(systemName: "checklist")
                            .fontWeight(.black)
                        Text("chapterDescription")
                    }
                    .tag(ControlNavigationTab.chapterDescription)
                }
            }
            .frame(minHeight: minHeight)
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #else
            .tabViewStyle(.automatic)
            #endif
            .sensoryFeedback(Const.sensoryFeedback, trigger: navManager.playerTab)
            .onSizeChange { size in
                SheetPositionReader.shared.playerContentViewHeight = size.height
            }

            PlayerBottomShadow(height: shadowHeight)
                .opacity(navManager.showMenu ? 1 : 0)

            if !hidePlayerPageIndicator {
                PlayerPageControl()
                    .padding(
                        .bottom,
                        compactSize
                            ? 0
                            : (Const.minSheetDetent - 21)
                    )
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .opacity(navManager.showMenu ? 1 : 0)
            }
        }
        // TODO: enable safe area? Last checked on iOS 26 beta 8 (flickering issue)
    }

    var shadowHeight: CGFloat {
        hidePlayerPageIndicator
            ? Const.minSheetDetent
            : Const.minSheetDetent + fadeOutHeight
    }
}
