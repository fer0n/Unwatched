//
//  InboxToolbar.swift
//  Unwatched
//

import SwiftUI

struct UndoToolbarButton: ToolbarContent {
    @Environment(TinyUndoManager.self) private var undoManager

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                undoManager.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .accessibilityLabel("undo")
            .opacity(undoManager.canUndo ? 1 : 0)
            .font(.footnote)
            .fontWeight(.bold)
            //            #if os(iOS)
            //            CoreRefreshButton(refreshOnlySubscription: refreshOnlySubscription)
            //            #else
            //            CoreRefreshButton(refreshOnlySubscription: refreshOnlySubscription)
            //                .buttonStyle(.borderless)
            //            #endif
        }
    }
}

struct InboxToolbar: ViewModifier {
    @Environment(\.modelContext) var modelContext
    var showCancelButton: Bool = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                if showCancelButton {
                    DismissToolbarButton()
                }
                UndoToolbarButton()
                ToolbarSpacerWorkaround()
                RefreshToolbarButton()
            }
    }
}

extension View {
    func inboxToolbar(_ showCancelButton: Bool = false) -> some View {
        modifier(InboxToolbar(showCancelButton: showCancelButton))
    }
}
