//
//  ConfirmableMenuButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ConfirmableMenuButton<Content: View>: View {
    let label: Content
    let action: () -> Void

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Content) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Menu {
            Button(
                "confirm",
                systemImage: "checkmark",
                role: .destructive,
                action: action
            )

            Button("cancel", systemImage: Const.clearNoFillSF, action: { })
        } label: {
            label
        }
    }
}
