//
//  TextFieldClearButton.swift
//  Unwatched
//

import SwiftUI

struct TextFieldClearButton: View {
    @Binding var text: String

    var body: some View {
        Button {
            text = ""
        } label: {
            Image(systemName: Const.clearSF)
        }
        .foregroundStyle(.secondary)
    }
}
