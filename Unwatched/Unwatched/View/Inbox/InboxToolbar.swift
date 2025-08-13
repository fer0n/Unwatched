//
//  InboxToolbar.swift
//  Unwatched
//

import SwiftUI

struct UndoToolbarButton: ToolbarContent {
    @Environment(TinyUndoManager.self) private var undoManager

    var body: some ToolbarContent {
        if undoManager.canUndo {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    undoManager.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .accessibilityLabel("undo")
                .font(.footnote)
                .fontWeight(.bold)
            }
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
                SyncStatusToolbarInfo()
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed)
                }
                RefreshToolbarButton()
            }
    }
}

extension View {
    func inboxToolbar(_ showCancelButton: Bool = false) -> some View {
        modifier(InboxToolbar(showCancelButton: showCancelButton))
    }
}
