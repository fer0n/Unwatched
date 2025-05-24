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
    let enableHideControls: Bool
    let hideControls: Bool

    let setShowMenu: () -> Void
    let markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var sleepTimerVM: SleepTimerViewModel

    let fadeOutHeight: CGFloat = 55

    @State var minHeight: CGFloat?
    @Binding var autoHideVM: AutoHideVM

    var body: some View {
        @Bindable var navManager = navManager

        ZStack {
            TabView(selection: $navManager.playerTab) {
                PlayerControls(compactSize: compactSize,
                               horizontalLayout: horizontalLayout,
                               enableHideControls: enableHideControls,
                               hideControls: hideControls,
                               setShowMenu: setShowMenu,
                               markVideoWatched: markVideoWatched,
                               sleepTimerVM: sleepTimerVM,
                               minHeight: $minHeight,
                               autoHideVM: $autoHideVM)
                    .padding(.vertical, compactSize ? 5 : 0)
                    .verticalSwipeGesture(
                        disableGesture: compactSize,
                        onSwipeUp: setShowMenu,
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
                        setShowMenu: setShowMenu
                    )
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

            bottomShadow
                .opacity(navManager.showMenu ? 1 : 0)

            if !hidePlayerPageIndicator {
                pageControl
                    .padding(.bottom, compactSize ? 0 : Const.minSheetDetent - 3)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .opacity(navManager.showMenu ? 1 : 0)
            }
        }
    }

    var pageControl: some View {
        PageControl(
            currentPage: Binding(
                get: { navManager.playerTab.rawValue },
                set: { newValue in
                    if let newValue, let newTab = ControlNavigationTab(rawValue: newValue) {
                        navManager.playerTab = newTab
                    }
                }
            ),
            numberOfPages: 2,
            normalColor: .automaticBlack
        )
        .clipShape(Capsule())
    }

    var bottomShadow: some View {
        VStack(spacing: 0) {
            Spacer()

            Color.black
                .allowsHitTesting(false)
                .frame(height: fadeOutHeight)
                .mask(LinearGradient(gradient: Gradient(
                    stops: [
                        .init(color: .black.opacity(0.9), location: 0),
                        .init(color: .black.opacity(0.3), location: 0.55),
                        .init(color: .clear, location: 1)
                    ]
                ), startPoint: .bottom, endPoint: .top))

            Color.black
                .frame(height: compactSize ? 0 : Const.minSheetDetent - 10)
        }
    }
}
