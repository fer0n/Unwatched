//
//  TextFieldClearButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TextFieldClearButton: View {
    @Binding var text: String

    var body: some View {
        Button {
            text = ""
        } label: {
            Image(systemName: Const.clearSF)
        }
        .foregroundStyle(.secondary)
        .opacity(text.isEmpty ? 0 : 1)
        .frame(width: text.isEmpty ? 0 : nil)
        .accessibilityLabel("clearText")
    }
}
