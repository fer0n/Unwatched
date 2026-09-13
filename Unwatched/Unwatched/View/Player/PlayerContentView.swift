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

    var sleepTimerVM: SleepTimerViewModel
    let fadeOutHeight: CGFloat = 25

    /// An audio episode has no video above the pages, so the player rides along inside the first one: swiping to the
    /// description takes the cover art with it and leaves the mini player.
    var inlinePlayer: PlayerView?
    /// Passed in rather than re-derived: while the menu covers the page, `inlinePlayer` is the mini-player bar and
    /// has to stay pinned to the top instead of filling what's left.
    var hideMiniPlayer: Bool = true

    @State var minHeight: CGFloat?
    @State private var scrolledPage: ControlNavigationTab?
    @Binding var autoHideVM: AutoHideVM

    /// Stands in until the controls have measured themselves in *this* instance: rotating to
    /// landscape tears the view down, and without a reservation the website player takes the whole
    /// column first and the controls then measure at zero and never come back.
    /// The persisted height, not `SheetPositionReader`'s — reading the observable one here would
    /// tie every frame of its height animation to this view.
    private var reservedControlHeight: CGFloat? {
        guard player.limitHeight || compactSize else { return nil }
        let stored = UserDefaults.standard.double(forKey: Const.playerControlHeight)
        return stored > 0 ? stored : nil
    }

    var body: some View {
        @Bindable var navManager = navManager

        ZStack {
            pages
                .frame(minHeight: minHeight ?? reservedControlHeight)
                .playerTabHaptic()
                .onSizeChange { size in
                    SheetPositionReader.shared.playerContentViewHeight = size.height
                }

            PlayerBottomShadow(height: shadowHeight)
                .ignoresSafeArea(edges: .bottom)
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

    @ViewBuilder
    var pages: some View {
        if inlinePlayer != nil {
            livePages
        } else {
            tabPages
        }
    }

    @ViewBuilder
    var tabPages: some View {
        @Bindable var navManager = navManager

        TabView(selection: $navManager.playerTab) {
            controlsPage
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                        .fontWeight(.black)
                    Text("controls")
                }
                .tag(ControlNavigationTab.controls)

            if let video = player.video {
                chapterDescriptionPage(video)
                    .tabItem {
                        Image(systemName: "checklist")
                            .fontWeight(.black)
                        Text("chapterDescription")
                    }
                    .tag(ControlNavigationTab.chapterDescription)
            }
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #else
        .tabViewStyle(.automatic)
        #endif
    }

    /// Paging `ScrollView` rather than a `TabView`: an unloaded tab page gets no updates.
    @ViewBuilder
    var livePages: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                controlsPage
                    .containerRelativeFrame(.horizontal)
                    .id(ControlNavigationTab.controls)

                if let video = player.video {
                    chapterDescriptionPage(video)
                        .containerRelativeFrame(.horizontal)
                        .id(ControlNavigationTab.chapterDescription)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        // the pages carry their own edge effects
        #if os(iOS)
        .scrollEdgeEffectHidden(for: .all)
        #endif
        .scrollPosition(id: $scrolledPage)
        .onAppear { scrolledPage = navManager.playerTab }
        .onChange(of: scrolledPage) {
            guard let scrolledPage, scrolledPage != navManager.playerTab else { return }
            navManager.playerTab = scrolledPage
        }
        .onPlayerTabChange {
            guard scrolledPage != navManager.playerTab else { return }
            withAnimation {
                scrolledPage = navManager.playerTab
            }
        }
    }

    @ViewBuilder
    var controlsPage: some View {
        if let inlinePlayer {
            VStack(spacing: 0) {
                inlinePlayer
                    // art always claims the leftover height so the controls keep their place; only its own alignment
                    // shifts — centered while it fills, pinned up as the mini bar
                    .frame(maxHeight: .infinity, alignment: hideMiniPlayer ? .center : .top)

                playerControls
                    // the art above takes the height that's left, not the other way around
                    .layoutPriority(1)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            // the art's bounce would move the description page sharing this row
            .transaction { transaction in
                if navManager.playerTab != .controls {
                    transaction.disablesAnimations = true
                }
            }
        } else {
            playerControls
        }
    }

    @ViewBuilder
    var playerControls: some View {
        PlayerControls(compactSize: compactSize,
                       horizontalLayout: horizontalLayout,
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
    }

    @ViewBuilder
    func chapterDescriptionPage(_ video: Video) -> some View {
        if inlinePlayer != nil {
            VStack(spacing: 0) {
                InlineMiniPlayer {
                    navManager.playerTab = .controls
                }

                chapterDescription(video)
                    // below the mini player the page's top isn't on the safe area, so the soft edge effect has no
                    // region to draw in and the text would cut off hard under the bar
                    .overlay {
                        PlayerTopShadow()
                    }
            }
        } else {
            chapterDescription(video)
        }
    }

    func chapterDescription(_ video: Video) -> some View {
        ChapterDescriptionView(
            video: video,
            bottomSpacer: descriptionBottomSpacer,
            showThumbnail: false,
            showActions: false
        )
        #if !os(visionOS)
        .softSafeAreaBarSpacer(edge: .top)
        #endif
        #if os(iOS)
        .softSafeAreaBarSpacer(edge: .bottom, padding: aboveSheetPadding)
        #endif
    }

    private var descriptionBottomSpacer: CGFloat {
        #if os(iOS)
        0
        #else
        fadeOutHeight + Const.minSheetDetent
        #endif
    }

    #if os(iOS)
    private var aboveSheetPadding: CGFloat {
        navManager.showMenu ? Const.minSheetDetent - 10 : 10
    }
    #endif

    var shadowHeight: CGFloat {
        hidePlayerPageIndicator
            ? Const.minSheetDetent
            : Const.minSheetDetent + fadeOutHeight
    }
}
