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
        func parse(_ source: String) -> AttributedString {
            (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
        }
        var parsed = parse(limit.map { Self.head(of: text, limit: $0) } ?? text)
        if let limit, parsed.characters.count < limit, text.count > limit * 2 {
            parsed = parse(text)
        }
        guard let limit, parsed.characters.count > limit else {
            self = parsed
            return
        }
        let end = parsed.characters.index(parsed.startIndex, offsetBy: limit)
        self = AttributedString(parsed[parsed.startIndex..<end])
    }

    /// Ends on a line break where it can, so inline markup isn't cut open
    private static func head(of text: String, limit: Int) -> String {
        let head = text.prefix(limit * 2)
        guard let lineEnd = head.lastIndex(of: "\n"),
              head.distance(from: head.startIndex, to: lineEnd) >= limit else {
            return String(head)
        }
        return String(head[..<lineEnd])
    }
}
