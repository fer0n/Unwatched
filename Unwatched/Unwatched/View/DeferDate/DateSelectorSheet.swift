//
//  DateSelectorSheet.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DateSelectorSheet: ViewModifier {
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @Environment(\.modelContext) var modelContext

    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @State private var sheetHeight: CGFloat = 600

    func body(content: Content) -> some View {
        @Bindable var player = player
        @Bindable var navManager = navManager

        content
            .sheet(isPresented: $navManager.showDeferDateSelector, onDismiss: onDismiss) {
                ScrollView {
                    DeferDateSelector(
                        video: player.video,
                        detectedDate: $player.deferVideoDate,
                        onSuccess: handleSuccess
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .onSizeChange { size in
                        Task {
                            // workaround: without Taskt, the sheet height is stuck on 0
                            sheetHeight = size.height
                        }
                    }
                    .presentationDetents([.height(sheetHeight)])
                    .tint(theme.color)
                }
            }
            .onChange(of: player.deferVideoDate) {
                if player.deferVideoDate != nil {
                    navManager.showDeferDateSelector = true
                }
            }
    }

    func onDismiss() {
        if !SheetPositionReader.shared.landscapeFullscreen {
            navManager.showMenu = true
        }
    }

    func handleSuccess() {
        player.loadTopmostVideoFromQueue(modelContext: modelContext)
    }
}

extension View {
    func dateSelectorSheet(
    ) -> some View {
        self.modifier(
            DateSelectorSheet()
        )
    }
}
