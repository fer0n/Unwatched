//
//  AttributedString.swift
//  UnwatchedShared
//

import Foundation

public extension AttributedString {
    init(inlineMarkdown text: String, limit: Int? = nil) {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        let parsed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        guard let limit, parsed.characters.count > limit else {
            self = parsed
            return
        }
        let end = parsed.characters.index(parsed.startIndex, offsetBy: limit)
        self = AttributedString(parsed[parsed.startIndex..<end])
    }
}
