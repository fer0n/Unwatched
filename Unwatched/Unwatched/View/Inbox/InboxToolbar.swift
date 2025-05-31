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
                undoRedoToolbarButton
                ToolbarSpacerWorkaround()
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
            .opacity(modelContext.undoManager?.canUndo == true ? 1 : 0)
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
