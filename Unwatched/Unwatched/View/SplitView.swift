//
//  SplitView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MacOSSplitView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player

    let bigScreen: Bool
    let isLandscape: Bool
    let landscapeFullscreen: Bool
    let breakpoint: CGFloat = 200

    var body: some View {
        @Bindable var navManager = navManager

        NavigationSplitView(columnVisibility: $navManager.columnVisibility) {
            MenuView(isSidebar: true)
                .toolbar(navManager.isMacosFullscreen ? .hidden : .visible)
                .navigationSplitViewColumnWidth(min: 320, ideal: 350, max: 450)
        } detail: {
            GeometryReader { proxy in
                let horizontalLayout = horizontalLayout(proxy.size)

                VideoPlayer(
                    compactSize: bigScreen,
                    horizontalLayout: horizontalLayout,
                    limitWidth: shouldLimitWidth(proxy.size, horizontalLayout),
                    landscapeFullscreen: landscapeFullscreen,
                    hideControls: detailOnly
                )
                #if os(macOS)
                .toolbar(removing: .title)
                .toolbarBackground(
                    showToolbarBackground ? .automatic : .hidden,
                    for: .windowToolbar
                )
                #endif
                .environment(\.colorScheme, .dark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .edgesIgnoringSafeArea(.all)
        }
    }

    func horizontalLayout(_ size: CGSize) -> Bool {
        (isLandscape && bigScreen) &&
            (navManager.isMacosFullscreen || spaceRequiresHorizontalLayout(size))
    }

    func shouldLimitWidth(_ size: CGSize, _ horizontalLayout: Bool) -> Bool {
        if horizontalLayout {
            size.width < 750
        } else {
            size.width < 600
        }
    }

    func spaceRequiresHorizontalLayout(_ size: CGSize) -> Bool {
        let videoAspectRatio = player.videoAspectRatio
        let videoHeight =  size.width / videoAspectRatio
        let remainingHeight = size.height - videoHeight
        return remainingHeight < breakpoint
    }

    var detailOnly: Bool {
        navManager.isSidebarHidden
    }

    var showToolbarBackground: Bool {
        navManager.isMacosFullscreen && navManager.isSidebarHidden
    }
}

struct IOSSPlitView: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false

    let proxy: GeometryProxy
    let bigScreen: Bool
    let isLandscape: Bool
    let landscapeFullscreen: Bool

    var body: some View {
        layout {
            VideoPlayer(
                compactSize: bigScreen,
                horizontalLayout: hideControlsFullscreen,
                landscapeFullscreen: landscapeFullscreen,
                hideControls: hideControlsFullscreen
            )
            .frame(maxHeight: .infinity)
            .environment(\.layoutDirection, .leftToRight)

            if bigScreen && !hideControlsFullscreen {
                MenuView(isSidebar: true)
                    .frame(maxWidth: isLandscape
                            ? min(proxy.size.width * 0.4, sidebarWidth)
                            : nil,
                           maxHeight: isLandscape
                            ? nil
                            : proxy.size.height * 0.4)
                    .setColorScheme()
                    .if(isLandscape) { view in
                        view.clipShape(RoundedRectangle(
                            cornerRadius: 9, style: .continuous
                        ))
                    }
                    .edgesIgnoringSafeArea(.all)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .animation(.default, value: hideControlsFullscreen)
    }

    var layout: AnyLayout {
        isLandscape
            ? AnyLayout(HStackLayout())
            : AnyLayout(VStackLayout())
    }

    var sidebarWidth: Double {
        dynamicTypeSize >= .accessibility1 ? 410 : 360
    }
}
