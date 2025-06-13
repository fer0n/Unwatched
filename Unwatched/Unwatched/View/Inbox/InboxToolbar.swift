//
//  InboxToolbar.swift
//  Unwatched
//

import SwiftUI

struct InboxToolbar: ViewModifier {
    @Environment(\.modelContext) var modelContext

    var showCancelButton: Bool = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                if showCancelButton {
                    DismissToolbarButton()
                }
                if modelContext.undoManager?.canUndo == true {
                    undoRedoToolbarButton
                }
                SyncStatusToolbarInfo()
                ToolbarSpacer(.fixed)
                RefreshToolbarButton()
            }
    }

    var undoRedoToolbarButton: some ToolbarContent {
        // Workaround: having this be its own view
        // doesn't work for some reason
        ToolbarItem(placement: .cancellationAction) {
            Button {
                modelContext.undoManager?.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .accessibilityLabel("undo")
            .font(.footnote)
            .fontWeight(.bold)
        }
    }
}

extension View {
    func inboxToolbar(_ showCancelButton: Bool = false) -> some View {
        modifier(InboxToolbar(showCancelButton: showCancelButton))
    }
}
