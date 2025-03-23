//
//  SplitView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MacOSSplitView: View {
    @Environment(NavigationManager.self) var navManager

    let bigScreen: Bool
    let isLandscape: Bool
    let landscapeFullscreen: Bool

    var body: some View {
        @Bindable var navManager = navManager

        NavigationSplitView(columnVisibility: $navManager.columnVisibility) {
            MenuView(isSidebar: true)
                .navigationSplitViewColumnWidth(min: 320, ideal: 350, max: 450)
                .setColorScheme()
                .showSidebarToggle()
        } detail: {
            VideoPlayer(
                compactSize: bigScreen,
                showInfo: !bigScreen || (isLandscape && bigScreen) && !detailOnly,
                horizontalLayout: detailOnly && (isLandscape && bigScreen),
                landscapeFullscreen: landscapeFullscreen,
                hideControls: detailOnly
            )
        }
    }

    var detailOnly: Bool {
        navManager.isSidebarHidden
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
                showInfo: !bigScreen || (isLandscape && bigScreen) && !hideControlsFullscreen,
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
