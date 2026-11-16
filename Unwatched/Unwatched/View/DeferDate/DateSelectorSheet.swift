//
//  DateSelectorSheet.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import SwiftData

struct DateSelectorSheet: ViewModifier {
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @Environment(\.modelContext) var modelContext

    func body(content: Content) -> some View {
        @Bindable var player = player
        @Bindable var navManager = navManager

        content
            .sheet(isPresented: $navManager.showDeferDateSelector, onDismiss: onDismiss) {
                DeferDateSheetContent(
                    video: player.video,
                    detectedDate: $player.deferVideoDate,
                    onSuccess: handleSuccess
                )
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

struct DeferDateSheetContent: View {
    /// Kept across presentations: starting each one from a guess resizes the sheet as it opens
    @MainActor private static var lastHeight: CGFloat = 600

    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @State private var sheetHeight = Self.lastHeight

    let video: Video?
    var detectedDate: Binding<Date?>?
    var onSuccess: (() -> Void)?

    var body: some View {
        ScrollView {
            DeferDateSelector(
                video: video,
                detectedDate: detectedDate,
                onSuccess: onSuccess
            )
            .fixedSize(horizontal: false, vertical: true)
            .onSizeChange { size in
                Task {
                    // workaround: without a Task, the sheet height is stuck on 0
                    sheetHeight = size.height
                    Self.lastHeight = size.height
                }
            }
            .presentationDetents([.height(sheetHeight)])
            .tint(theme.color)
        }
        // sheets inherit the presenter's font
        .font(.body)
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
