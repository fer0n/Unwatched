//
//  MenuValueStepper.swift
//  Unwatched
//

import SwiftUI

struct MenuValueStepper: View {
    var value: String
    var decrementLabel: LocalizedStringKey
    var incrementLabel: LocalizedStringKey
    var onDecrement: (() -> Void)?
    var onIncrement: (() -> Void)?

    var body: some View {
        ControlGroup {
            stepButton("minus", label: decrementLabel, action: onDecrement)
            Button { } label: {
                Text(verbatim: value)
            }
            // menu entries are diffed by title, so this stays apart from an equal entry below
            .id("currentValue")
            stepButton("plus", label: incrementLabel, action: onIncrement)
        }
        .controlGroupStyle(.compactMenu)
    }

    private func stepButton(
        _ systemImage: String,
        label: LocalizedStringKey,
        action: (() -> Void)?
    ) -> some View {
        Button {
            action?()
        } label: {
            Label(label, systemImage: systemImage)
        }
        .disabled(action == nil)
    }
}
