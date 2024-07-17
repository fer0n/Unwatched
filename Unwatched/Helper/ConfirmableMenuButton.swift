//
//  ConfirmableMenuButton.swift
//  Unwatched
//

import SwiftUI

struct ConfirmableMenuButton<Content: View>: View {
    let label: Content
    let action: () -> Void

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Content) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Menu {
            Button(role: .destructive) {
                action()
            } label: {
                Image(systemName: "checkmark")
                Text("confirm")
            }
            Button { } label: {
                Label("cancel", systemImage: "xmark")
            }
        } label: {
            label
        }
    }
}
