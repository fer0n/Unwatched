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

    var body: some View {
        @Bindable var navManager = navManager

        ZStack {
            pages
                .frame(minHeight: minHeight)
                .sensoryFeedback(Const.sensoryFeedback, trigger: navManager.playerTab)
                .onSizeChange { size in
                    SheetPositionReader.shared.playerContentViewHeight = size.height
                }

            bottomShadow
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

    /// Grown downwards into the bottom safe area, which the pages draw into but the layout around
    /// them stops short of: left at the container's edge the gradient ended in a hard cut with the
    /// description still scrolling past underneath it. The inset is zero wherever there is none to
    /// take, so this is the plain shadow everywhere else.
    var bottomShadow: some View {
        GeometryReader { proxy in
            let inset = proxy.safeAreaInsets.bottom

            PlayerBottomShadow(height: shadowHeight + inset)
                .padding(.bottom, -inset)
        }
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
        .scrollPosition(id: $scrolledPage)
        .onAppear { scrolledPage = navManager.playerTab }
        .onChange(of: scrolledPage) {
            guard let scrolledPage, scrolledPage != navManager.playerTab else { return }
            navManager.playerTab = scrolledPage
        }
        .onChange(of: navManager.playerTab) {
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
            }
        } else {
            chapterDescription(video)
        }
    }

    @ViewBuilder
    func chapterDescription(_ video: Video) -> some View {
        ChapterDescriptionView(
            video: video,
            bottomSpacer: fadeOutHeight + Const.minSheetDetent,
            showThumbnail: false,
            showActions: false
        )
        .overlay {
            PlayerTopShadow()
        }
    }

    var shadowHeight: CGFloat {
        hidePlayerPageIndicator
            ? Const.minSheetDetent
            : Const.minSheetDetent + fadeOutHeight
    }
}

/// The mini player at the top of the description page, standing in for the cover art that swiped away with the first
/// page.
private struct InlineMiniPlayer: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.displayScale) private var displayScale

    var goToControls: () -> Void

    private static let imageSize: CGFloat = 60

    var body: some View {
        MiniPlayerLayout(hideMiniPlayer: false, handleMiniPlayerTap: goToControls) {
            // decoded at the size it's drawn at, not the full player's: scaling cover art down from 1400px+ in the
            // render pass aliases (see `PodcastArtwork`)
            CachedImageView(
                imageUrl: player.video?.displayThumbnailUrl,
                maxPixelSize: ceil(Self.imageSize * displayScale)
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: Const.podcastSF)
                    .foregroundStyle(.secondary)
            }
            .frame(width: Self.imageSize, height: Self.imageSize)
            .background(Color.playerBackgroundColor)
            .clipShape(RoundedRectangle(
                cornerRadius: Const.videoPlayerCornerRadius,
                style: .continuous
            ))
            .padding(.leading, PlayerView.miniPlayerHorizontalPadding)
            .contentShape(Rectangle())
            .onTapGesture(perform: goToControls)
        }
    }
}
