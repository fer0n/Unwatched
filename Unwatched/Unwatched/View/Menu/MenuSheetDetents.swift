//
//  MenuSheetDetents.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MenuSheetDetents: ViewModifier {
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player

    var allowPlayerControlHeight: Bool
    var landscapeFullscreen: Bool
    var proxy: GeometryProxy

    @State var hasVideo = true

    func body(content: Content) -> some View {
        @Bindable var sheetPos = sheetPos

        content
            .modifier(AnimatableDetents(
                selectedDetent: $sheetPos.selectedDetent,
                allowMinSheet: sheetPos.allowMinSheet && hasVideo,
                allowPlayerControlHeight: allowPlayerControlHeight,
                maxSheetHeight: sheetPos.maxSheetHeight,
                playerControlHeight: sheetPos.playerControlHeight,
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
            // no cancel button shown in landscape
            .interactiveDismissDisabled(!landscapeFullscreen || player.video == nil)
            .disabled(
                sheetPos.isMinimumSheet
                    && !navManager.hasSheetOpen
                    && !navManager.showBrowser
                    && !landscapeFullscreen
                    && !navManager.showPremiumOffer
                    && player.video != nil
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

extension View {
    func menuSheetDetents(
        allowPlayerControlHeight: Bool = false,
        landscapeFullscreen: Bool = false,
        proxy: GeometryProxy
    ) -> some View {
        self.modifier(
            MenuSheetDetents(
                allowPlayerControlHeight: allowPlayerControlHeight,
                landscapeFullscreen: landscapeFullscreen,
                proxy: proxy
            )
        )
    }
}
