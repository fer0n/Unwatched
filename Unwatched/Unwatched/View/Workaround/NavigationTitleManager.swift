//
//  NavigationTitleManager.swift
//  Unwatched
//

import SwiftUI

/// Workaround: NavigationSplitView with NavigationStack inside Sidebar breaks content on macOS 26 (beta 8)
@Observable
final class NavigationTitleManager {
    private var titleStack: [LocalizedStringKey] = []

    var title: LocalizedStringKey? {
        titleStack.last
    }

    func push(_ title: LocalizedStringKey?) {
        guard let title else { return }
        titleStack.append(title)
    }

    func replaceTop(_ title: LocalizedStringKey?) {
        guard let title else { return }
        if !titleStack.isEmpty {
            titleStack[titleStack.count - 1] = title
        } else {
            titleStack.append(title)
        }
    }

    func pop() {
        _ = titleStack.popLast()
    }

    func clear() {
        titleStack.removeAll()
    }
}
