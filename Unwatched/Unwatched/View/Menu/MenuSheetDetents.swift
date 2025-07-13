//
//  MenuSheetDetents.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MenuSheetDetents: ViewModifier, KeyboardReadable {
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player

    @State private var isKeyboardVisible = false

    var allowMaxSheetHeight: Bool
    var allowPlayerControlHeight: Bool
    var landscapeFullscreen: Bool

    func body(content: Content) -> some View {
        @Bindable var sheetPos = sheetPos

        content
            .presentationDetents(detents, selection: $sheetPos.selectedDetent)
            .presentationBackgroundInteraction(.enabled)
            .presentationContentInteraction(.scrolls)
            .onGlobalMinYChange(action: sheetPos.handleSheetMinYUpdate)
            .presentationDragIndicator(.hidden)
            // no cancel button shown in landscape
            .interactiveDismissDisabled(!landscapeFullscreen && player.video != nil)
            .disabled(
                sheetPos.isMinimumSheet
                    && !navManager.hasSheetOpen
                    && navManager.openTabBrowserUrl == nil
                    && !landscapeFullscreen
                    && player.video != nil
            )
            #if os(iOS)
            .onReceive(keyboardPublisher) { newIsKeyboardVisible in
                isKeyboardVisible = newIsKeyboardVisible
            }
            #endif
            .onChange(of: detents, initial: true) {
                if !detents.contains(sheetPos.selectedDetent)
                    && !(navManager.hasSheetOpen || navManager.tab == .browser) {
                    if detents.contains(.height(sheetPos.maxSheetHeight)) {
                        sheetPos.selectedDetent = .height(sheetPos.maxSheetHeight)
                    } else {
                        sheetPos.selectedDetent = detents.first ?? .large
                    }
                }
            }
            .sensoryFeedback(Const.sensoryFeedback, trigger: sheetPos.selectedDetent) { old, new in
                ![old, new].contains(.height(sheetPos.maxSheetHeight))
            }
            .sensoryFeedback(Const.sensoryFeedback, trigger: sheetPos.swipedBelow) { _, _ in
                !landscapeFullscreen
            }
    }

    var detents: Set<PresentationDetent> {
        allowMaxSheetHeight
            ? Set([.height(Const.minSheetDetent), .height(sheetPos.maxSheetHeight)])
            .union(
                allowPlayerControlHeight
                    ? [.height(sheetPos.playerControlHeight)]
                    : []

            )
            .union(isKeyboardVisible ? [.large] : [])
            : [.large]
    }
}

extension View {
    func menuSheetDetents(
        allowMaxSheetHeight: Bool = false,
        allowPlayerControlHeight: Bool = false,
        landscapeFullscreen: Bool = false
    ) -> some View {
        self.modifier(
            MenuSheetDetents(
                allowMaxSheetHeight: allowMaxSheetHeight,
                allowPlayerControlHeight: allowPlayerControlHeight,
                landscapeFullscreen: landscapeFullscreen
            )
        )
    }
}
