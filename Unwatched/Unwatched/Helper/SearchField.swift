//
//  SearchField.swift
//  Unwatched
//

import SwiftUI

struct SearchField: View {
    @Binding var text: DebouncedText

    var body: some View {
        TextField("searchLibrary", text: $text.debounced)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
    }
}

#Preview {
    @Previewable @State var text = DebouncedText()

    SearchField(text: $text)
}
