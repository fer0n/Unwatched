//
//  TranscriptSearch.swift
//  Unwatched
//

import SwiftUI

struct TranscriptSearch: View {
    @Binding var text: DebouncedText

    var body: some View {
        TextField(
            "searchTranscript",
            text: $text.val,
            prompt: Text("searchTranscript").foregroundColor(.gray)
        )
        .autocorrectionDisabled(true)
        #if os(iOS)
        .keyboardType(.webSearch)
        .textInputAutocapitalization(.never)
        #endif
        .submitLabel(.done)
        .foregroundStyle(.gray)
    }
}

#Preview {
    TranscriptSearch(text: .constant(DebouncedText()))
        .padding()
        .background(.blue)
}
