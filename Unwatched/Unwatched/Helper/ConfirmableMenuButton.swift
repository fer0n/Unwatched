//
//  ConfirmableMenuButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ConfirmableMenuButton<Content: View>: View {
    let label: Content
    let action: () -> Void
    let helperText: LocalizedStringKey?

    init(helperText: LocalizedStringKey? = nil, action: @escaping () -> Void, @ViewBuilder label: () -> Content) {
        self.helperText = helperText
        self.action = action
        self.label = label()
    }

    var body: some View {
        Menu {
            if let helperText {
                Section(helperText) {
                    buttonContent
                }
            } else {
                buttonContent
            }
        } label: {
            label
        }
        .tint(.red)
    }

    @ViewBuilder
    var buttonContent: some View {
        Button(
            "confirm",
            systemImage: "checkmark",
            role: .destructive,
            action: action
        )

        Button("cancel", systemImage: Const.clearNoFillSF, action: { })
            .tint(Color.automaticBlack)
    }
}
