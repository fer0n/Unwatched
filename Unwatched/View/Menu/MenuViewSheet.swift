//
//  MenuViewSheet.swift
//  Unwatched
//

import SwiftUI

struct MenuViewSheet: ViewModifier {
    @Environment(NavigationManager.self) var navManager
    @Environment(SheetPositionReader.self) var sheetPos

    var allowMaxSheetHeight: Bool
    var embeddingDisabled: Bool
    var showCancelButton: Bool
    var disableSheet: Bool

    func body(content: Content) -> some View {

        let detents: Set<PresentationDetent> = allowMaxSheetHeight
            ? Set([.height(sheetPos.maxSheetHeight)]).union(
                embeddingDisabled
                    ? []
                    : [.height(sheetPos.playerControlHeight)]
            )
            : [.large]

        let selectedDetent = Binding(
            get: { sheetPos.selectedDetent ?? detents.first ?? .large },
            set: { sheetPos.selectedDetent = $0 }
        )

        @Bindable var navManager = navManager

        content
            .sheet(isPresented: disableSheet ? .constant(false) : $navManager.showMenu) {
                ZStack {
                    Color.backgroundColor.ignoresSafeArea(.all)
                    MenuView(showCancelButton: showCancelButton)
                        .presentationDetents(detents, selection: selectedDetent)
                        .presentationBackgroundInteraction(
                            .enabled(upThrough: .height(sheetPos.maxSheetHeight))
                        )
                        .presentationContentInteraction(.scrolls)
                        .globalMinYTrackerModifier(onChange: sheetPos.handleSheetMinYUpdate)
                        .presentationDragIndicator(
                            navManager.searchFocused
                                ? .hidden
                                : .visible)
                }

            }
    }
}

extension View {
    func menuViewSheet(allowMaxSheetHeight: Bool,
                       embeddingDisabled: Bool,
                       showCancelButton: Bool,
                       disableSheet: Bool) -> some View {
        self.modifier(MenuViewSheet(allowMaxSheetHeight: allowMaxSheetHeight,
                                    embeddingDisabled: embeddingDisabled,
                                    showCancelButton: showCancelButton,
                                    disableSheet: disableSheet))
    }
}
