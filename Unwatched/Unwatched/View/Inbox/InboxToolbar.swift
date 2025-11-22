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
                .myTint(neutral: true)
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
                RefreshToolbarContent()
            }
    }
}

extension View {
    func inboxToolbar(_ showCancelButton: Bool = false) -> some View {
        modifier(InboxToolbar(showCancelButton: showCancelButton))
    }
}
import UnwatchedShared

#Preview {
    @Previewable @State var show = true

    NavigationStack {
        Button("Toggle Toolbar") {
            withAnimation {
                show.toggle()
            }
        }

        Text("Inbox Toolbar Preview")
            .toolbar {
                ToolbarItemGroup {
                    if show {
                        Image(systemName: "icloud.fill")
                    }

                    Image(systemName: Const.refreshSF)
                }
            }
    }
}
