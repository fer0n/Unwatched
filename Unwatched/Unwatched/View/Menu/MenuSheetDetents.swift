//
//  MenuSheetDetents.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MenuSheetDetents: ViewModifier {
    static let floatingSheetMargin: CGFloat = 8

    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player

    var allowPlayerControlHeight: Bool
    var landscapeFullscreen: Bool
    var floating: Bool
    var proxy: GeometryProxy

    @State var hasVideo = true

    func body(content: Content) -> some View {
        @Bindable var sheetPos = sheetPos

        content
            .modifier(AnimatableDetents(
                selectedDetent: $sheetPos.selectedDetent,
                // no minimized bar in fullscreen -> dragging down dismisses back to fullscreen
                allowMinSheet: sheetPos.allowMinSheet && hasVideo
                    && !player.tallFullscreenActive && !landscapeFullscreen,
                preferLarge: !hasVideo,
                allowPlayerControlHeight: allowPlayerControlHeight && sheetPos.fixedSheetHeight == nil,
                maxSheetHeight: sheetPos.maxSheetHeight,
                playerControlHeight: sheetPos.playerControlHeight,
                floatingInset: floatingInset
            ))
            .presentationBackgroundInteraction(.enabled)
            .presentationContentInteraction(.scrolls)
            .ignoresSafeArea(.all)
            .onChange(of: player.video != nil, initial: true) {
                // workaround: tab view becomes unresponsible when marking a
                // the final video (#short) as watched
                let newValue = player.video != nil
                if newValue {
                    hasVideo = true
                } else {
                    Task {
                        hasVideo = false
                    }
                }
            }
            .onGlobalMinYChange(action: {
                // workaround: for some reason, when switching to landscape this jumps
                // to the safe area value and causes a sensory feedback trigger
                if $0 != proxy.safeAreaInsets.bottom {
                    sheetPos.handleSheetMinYUpdate($0)
                }
            })
            // allow swipe-to-dismiss in landscape and portrait fullscreen (returns to the fullscreen player)
            .interactiveDismissDisabled(
                (!landscapeFullscreen && !player.tallFullscreenActive) || player.video == nil
            )
            .allowsHitTesting(
                !(sheetPos.isMinimumSheet
                    && !navManager.showBrowser
                    && !landscapeFullscreen
                    && !navManager.showPremiumOffer
                    && player.video != nil)
            )
            .sensoryFeedback(Const.sensoryFeedback, trigger: sheetPos.selectedDetent) { old, new in
                ![old, new].contains(.height(sheetPos.maxSheetHeight))
                    && sheetPos.allowMinSheet
            }
            .sensoryFeedback(Const.sensoryFeedback, trigger: sheetPos.swipedBelow) { _, _ in
                !landscapeFullscreen
            }
    }
}

extension MenuSheetDetents {
    var floatingInset: CGFloat {
        floating ? max(0, proxy.safeAreaInsets.bottom - Self.floatingSheetMargin) : 0
    }
}

extension View {
    func menuSheetDetents(
        allowPlayerControlHeight: Bool = false,
        landscapeFullscreen: Bool = false,
        floating: Bool = false,
        proxy: GeometryProxy
    ) -> some View {
        self.modifier(
            MenuSheetDetents(
                allowPlayerControlHeight: allowPlayerControlHeight,
                landscapeFullscreen: landscapeFullscreen,
                floating: floating,
                proxy: proxy
            )
        )
    }
}
