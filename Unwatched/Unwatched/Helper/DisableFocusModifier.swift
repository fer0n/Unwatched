//
//  DisableFocusModifier.swift
//  Unwatched
//

import SwiftUI

struct DisableFocusModifier: ViewModifier {
    @FocusState var focus: Bool

    func body(content: Content) -> some View {
        content
            .focused($focus)
            .onChange(of: focus) {
                if focus {
                    Task { @MainActor in
                        focus = false
                    }
                }
            }
    }
}

extension View {
    func disableFocus() -> some View {
        modifier(DisableFocusModifier())
    }
}
