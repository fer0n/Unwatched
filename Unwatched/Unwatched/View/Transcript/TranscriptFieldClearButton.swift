//
//  TranscriptFieldClearButton.swift
//  Unwatched
//

import SwiftUI

struct TranscriptFieldClearButton: View {
    @Binding var text: DebouncedText

    var body: some View {
        TextFieldClearButton(text: $text.val)
    }
}
