//
//  DescriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DescriptionDetailView: View {
    var description: String?

    var body: some View {
        if let description {
            Text(Self.attributed(description))
                .textSelection(.enabled)
                .myTint()
        }
    }

    /// Markdown is parsed per line so emphasis can't run across line breaks, then joined into one `AttributedString`
    /// so the whole description is a single selectable block.
    private static func attributed(_ description: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        let lines = description.split(separator: "\n", omittingEmptySubsequences: false)

        return lines.enumerated().reduce(into: AttributedString()) { result, item in
            let (index, line) = item
            if index > 0 {
                result.append(AttributedString("\n"))
            }
            let text = String(line)
            result.append((try? AttributedString(markdown: text, options: options))
                            ?? AttributedString(text))
        }
    }
}

#Preview {
    DescriptionDetailView(description: Video.getDummy().description)
}
