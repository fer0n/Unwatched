//
//  KeyboardShortcut+Help.swift
//  Unwatched
//

import SwiftUI

extension KeyboardShortcut {
    /// e.g. "⇧W"
    var symbol: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + key.symbol
    }
}

private extension KeyEquivalent {
    var symbol: String {
        switch self {
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .space: return "Space"
        case .escape: return "⎋"
        default: return String(character).uppercased()
        }
    }
}

extension View {
    /// Tooltip with the shortcuts appended, e.g. "Mark Watched (⇧W)"
    func help(_ title: String, shortcuts: [KeyboardShortcut?]) -> some View {
        let symbols = shortcuts.compactMap { $0?.symbol }
        let text = symbols.isEmpty ? title : "\(title) (\(symbols.joined(separator: " ")))"
        return help(text)
    }

    func help(_ title: String, shortcut: KeyboardShortcut?) -> some View {
        help(title, shortcuts: [shortcut])
    }
}
