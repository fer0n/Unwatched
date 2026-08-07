//
//  ButtonWithMenu.swift
//  Unwatched
//

import SwiftUI

struct MenuAction: Identifiable {
    enum Icon {
        case system(String)
        case asset(String)
        case none
    }

    let id = UUID()
    let title: String
    let icon: Icon
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.init(title, icon: .system(systemImage), action: action)
    }

    init(_ title: String, icon: Icon = .none, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
}

/// Actions of separate groups are drawn with a divider between them.
struct MenuActionGroup: Identifiable {
    let id = UUID()
    let title: String?
    let actions: [MenuAction]

    init(title: String? = nil, _ actions: [MenuAction]) {
        self.title = title
        self.actions = actions
    }
}

extension View {
    /// A button whose long press opens a context menu built from `groups`.
    ///
    /// Workaround: on iOS, since 26, SwiftUI's `contextMenu` stops tracking the finger once the
    /// menu is open, so pressing, dragging onto an entry and releasing selects nothing. A
    /// `Menu`'s `primaryAction` variant doesn't share that bug — a tap runs `onTap` and a long
    /// press opens the menu, with drag-to-select working correctly. Other platforms render the
    /// same data as a plain `contextMenu`, since they don't have the bug and a primary-action
    /// `Menu` renders as a visible split button there. Verified against iOS 26.5.
    ///
    /// To undo once SwiftUI's `contextMenu` tracks the finger again: make the iOS branch below
    /// use `swiftUIVersion` too, then inline it at the call sites.
    @ViewBuilder
    func buttonWithMenu(
        accessibilityLabel: String,
        groups: [MenuActionGroup],
        onTap: @escaping () -> Void
    ) -> some View {
        #if os(iOS)
        if groups.contains(where: { !$0.actions.isEmpty }) {
            Menu {
                menuContent(groups)
            } label: {
                self
            } primaryAction: {
                onTap()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        } else {
            Button(action: onTap) {
                self
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
        #else
        swiftUIVersion(accessibilityLabel: accessibilityLabel, groups: groups, onTap: onTap)
        #endif
    }

    private func swiftUIVersion(
        accessibilityLabel: String,
        groups: [MenuActionGroup],
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            self
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .contextMenu {
            menuContent(groups)
        }
    }

    @ViewBuilder
    private func menuContent(_ groups: [MenuActionGroup]) -> some View {
        ForEach(groups) { group in
            Section(group.title.map { LocalizedStringKey($0) } ?? "") {
                ForEach(group.actions) { action in
                    Button(action: action.action) {
                        Text(action.title)
                        action.icon.image
                    }
                }
            }
        }
    }
}

extension MenuAction.Icon {
    @ViewBuilder
    var image: some View {
        switch self {
        case .system(let name): Image(systemName: name)
        case .asset(let name): Image(name)
        case .none: EmptyView()
        }
    }
}
