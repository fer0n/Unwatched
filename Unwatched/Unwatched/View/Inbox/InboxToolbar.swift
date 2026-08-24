//
//  InboxToolbar.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

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
                .keyboardShortcut("z", modifiers: .command)
                .accessibilityLabel("undo")
                .font(.footnote)
                .fontWeight(.bold)
                .myTint(neutral: true)
            }
        }
    }
}

/// Shared picker content for the inbox sort order, used by the toolbar menu and the settings screen
struct InboxSortOrderPicker: View {
    @Binding var oldestFirst: Bool

    var body: some View {
        Picker("inboxSorting", selection: $oldestFirst) {
            Label("inboxNewestFirst", systemImage: "arrow.down").tag(false)
            Label("inboxOldestFirst", systemImage: "arrow.up").tag(true)
        }
    }
}

/// Switches the inbox between list and cards, long press sorts it instead
struct InboxAppearanceToolbarButton: ToolbarContent {
    @AppStorage(Const.inboxAppearance) private var inboxAppearance: InboxAppearance = .cards
    @AppStorage(Const.inboxOldestFirst) private var oldestFirst: Bool = false

    var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Menu {
                InboxSortOrderPicker(oldestFirst: $oldestFirst)
                    .pickerStyle(.inline)
            } label: {
                if inboxAppearance == .cards {
                    Image("line.3.text.square.stack.fill")
                } else {
                    Image(systemName: "list.bullet")
                }
            } primaryAction: {
                inboxAppearance = inboxAppearance == .cards ? .list : .cards
            }
            .accessibilityLabel("inboxAppearance")
            // same size as the refresh button next to it
            .font(.footnote)
            .fontWeight(.bold)
            .myTint(neutral: true)
        }
    }
}

struct InboxToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                UndoToolbarButton()
                ToolbarSpacerWorkaround()
                InboxAppearanceToolbarButton()
                RefreshToolbarContent()
            }
    }
}

extension View {
    func inboxToolbar() -> some View {
        modifier(InboxToolbar())
    }
}

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
