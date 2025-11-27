//
//  DescriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DescriptionDetailView: View {
    var description: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let description {
                let texts = description.split(separator: "\n", omittingEmptySubsequences: false)
                ForEach(Array(texts.enumerated()), id: \.offset) { _, text in
                    Text(LocalizedStringKey(String(text)))
                }
            }
        }
        .textSelection(.enabled)
        .myTint()
    }
}

#Preview {
    DescriptionDetailView(description: Video.getDummy().description)
}
