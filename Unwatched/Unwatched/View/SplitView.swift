//
//  SplitView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MacOSSplitView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @AppStorage(Const.isFakePip) var isFakePip = false

    let bigScreen: Bool
    let isLandscape: Bool
    let landscapeFullscreen: Bool
    let breakpoint: CGFloat = 200

    var body: some View {
        @Bindable var navManager = navManager

        NavigationSplitView(columnVisibility: isFakePip ? .constant(.detailOnly) : $navManager.columnVisibility) {
            MenuView(isSidebar: true)
                .toolbar(navManager.isMacosFullscreen || isFakePip ? .hidden : .visible)
                .navigationSplitViewColumnWidth(min: 320, ideal: 350, max: 450)
                .concentricMacWorkaround(corners: true)
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
                #if os(macOS)
                .overlay(alignment: .top) {
                    if isFakePip {
                        FakePipTitleBar()
                            .toolbar(.hidden, for: .windowToolbar)
                    }
                }
                #endif
            }
            .edgesIgnoringSafeArea(.vertical)
        }
        #if os(macOS)
        .onChange(of: isFakePip) { _, enabled in
            applyFakePipWindowState(enabled, aspectRatio: player.videoAspectRatio)
            navManager.toggleSidebar(show: !enabled)
        }
        .onChange(of: player.videoAspectRatio, initial: true) { _, newRatio in
            guard isFakePip, let window = mainWindow else { return }
            window.aspectRatio = NSSize(width: newRatio, height: 1)
            let width = window.contentLayoutRect.width
            window.setContentSize(NSSize(width: width, height: width / newRatio))
        }
        #endif
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

    #if os(macOS)
    var mainWindow: NSWindow? {
        NSApp.windows.first { $0.isVisible && $0.canBecomeMain }
    }

    @MainActor
    func applyFakePipWindowState(_ enabled: Bool, aspectRatio: Double) {
        guard let window = mainWindow else { return }

        window.level = enabled ? .floating : .normal

        if enabled {
            UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Const.preFakePipWindowFrame)

            window.aspectRatio = NSSize(width: aspectRatio, height: 1)
            window.contentMinSize = NSSize(width: 100, height: 100 / aspectRatio)

            // Defer so sidebar collapse finishes first
            Task { @MainActor in
                if let saved = UserDefaults.standard.string(forKey: Const.fakePipWindowFrame) {
                    let frame = NSRectFromString(saved)
                    if frame.size != .zero {
                        window.setFrame(frame, display: true, animate: true)
                        return
                    }
                }
                // First time: default to top-right corner
                let pipWidth: CGFloat = 400
                let pipHeight = pipWidth / aspectRatio
                let screen = window.screen ?? NSScreen.main
                if let visibleFrame = screen?.visibleFrame {
                    let margin: CGFloat = 16
                    window.setFrame(
                        NSRect(
                            x: visibleFrame.maxX - pipWidth - margin,
                            y: visibleFrame.maxY - pipHeight - margin,
                            width: pipWidth,
                            height: pipHeight
                        ),
                        display: true,
                        animate: true
                    )
                }
            }
        } else {
            UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Const.fakePipWindowFrame)

            // Clear aspect ratio lock before restoring
            window.resizeIncrements = NSSize(width: 1, height: 1)
            window.contentMinSize = NSSize(width: 800, height: 500)

            if let saved = UserDefaults.standard.string(forKey: Const.preFakePipWindowFrame) {
                let frame = NSRectFromString(saved)
                if frame.size != .zero {
                    window.setFrame(frame, display: true, animate: true)
                }
            }
        }
    }
    #endif
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
                horizontalLayout: hideControlsFullscreen && isLandscape,
                limitWidth: limitWidth,
                landscapeFullscreen: landscapeFullscreen,
                hideControls: hideControlsFullscreen,
                )
            .frame(maxHeight: .infinity)
            .environment(\.layoutDirection, .leftToRight)

            if bigScreen && !hideControlsFullscreen {
                MenuView(isSidebar: true)
                    .frame(maxWidth: menuWidth,
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
                    .transition(
                        isLandscape
                            ? .move(edge: .trailing)
                            : .offset(y: proxy.size.height * 0.4 + proxy.safeAreaInsets.bottom)
                    )
                    .environment(\.layoutDirection, .leftToRight)
                    #if os(visionOS)
                    .background(.regularMaterial)
                #endif
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .animation(.default, value: hideControlsFullscreen)
        #if os(iOS)
        .statusBar(hidden: hideControlsFullscreen && bigScreen)
        #endif
    }

    var layout: AnyLayout {
        isLandscape
            ? AnyLayout(HStackLayout(spacing: horizontalSpacing))
            : AnyLayout(VStackLayout())
    }

    var horizontalSpacing: Double {
        #if os(visionOS)
        0
        #else
        3
        #endif
    }

    var sidebarWidth: Double {
        #if os(visionOS)
        400
        #else
        dynamicTypeSize >= .accessibility1 ? 410 : 360
        #endif
    }

    var limitWidth: Bool {
        dynamicTypeSize > .large || (bigScreen && (proxy.size.width - (menuWidth ?? 0)) < 720)
    }

    var menuWidth: CGFloat? {
        isLandscape
            ? min(proxy.size.width * 0.4, sidebarWidth)
            : nil
    }
}
