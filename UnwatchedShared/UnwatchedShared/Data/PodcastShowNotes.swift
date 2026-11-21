//
//  PodcastShowNotes.swift
//  UnwatchedShared
//

import Foundation

/// Turns a show's HTML notes into the markdown-ish text the description views render.
public enum PodcastShowNotes {
    /// Non-breaking: plain spaces would read as a markdown code block.
    public static let listIndent = "\u{00A0}\u{00A0}"
    public static let listBullet = "\u{2022} "

    /// Podcast show notes are HTML, and for most shows they *are* the episode: a nested list of links.
    static func plainText(_ html: String?, keepLinks: Bool = true) -> String? {
        guard let notes = html, !notes.isEmpty else { return nil }
        let html = notes.replacing("\r\n", with: "\n").replacing("\r", with: "\n")

        var result = ""
        var listDepth = 0
        var linkHref: String?
        var openSpans: [OpenSpan] = []
        var awaitingItemText = false
        var index = html.startIndex

        while index < html.endIndex {
            let character = html[index]
            guard character == "<", let close = html[index...].firstIndex(of: ">") else {
                if character.isWhitespace, listDepth > 0 {
                    // a list's line breaks are markup, as in HTML
                    if let last = result.last, !last.isWhitespace {
                        result.append(" ")
                    }
                    index = html.index(after: index)
                    continue
                }
                awaitingItemText = false
                // inside a link the brackets are markdown syntax, so they can't stay as they are
                if linkHref != nil, !openSpans.contains(where: \.style.isCode), character == "[" || character == "]" {
                    result.append("\\")
                }
                result.append(character)
                index = html.index(after: index)
                continue
            }

            let tag = String(html[html.index(after: index)..<close])
            index = html.index(after: close)

            let isClosing = tag.hasPrefix("/")
            let name = tag
                .dropFirst(isClosing ? 1 : 0)
                .prefix { !$0.isWhitespace && $0 != "/" }
                .lowercased()

            // a span can't cross a block, a code span can't hold a link, and an unclosed one mustn't swallow the rest
            if blockTags.contains(name) {
                closeSpans(&openSpans, from: 0, in: &result)
            } else if name == "a", !isClosing, let code = openSpans.firstIndex(where: \.style.isCode) {
                closeSpans(&openSpans, from: code, in: &result)
            }

            if let style = inlineStyles[name] {
                if isClosing {
                    if let open = openSpans.lastIndex(where: { $0.style == style }) {
                        closeSpans(&openSpans, from: open, in: &result)
                    }
                } else if !openSpans.contains(where: { $0.style == style || $0.style.isCode }) {
                    openSpans.append(OpenSpan(style: style, offset: result.utf8.count))
                    result.append(style.marker)
                }
                continue
            }

            switch name {
            case "br" where listDepth > 0 && !awaitingItemText:
                trimTrailingSpaces(&result)
                result.append(lineSeparator)
            case "br", "p", "div", "h1", "h2", "h3", "h4", "h5", "h6":
                if listDepth > 0 {
                    if !awaitingItemText, !isClosing {
                        startLine(&result)
                    }
                } else {
                    result.append("\n")
                }
            case "ul", "ol":
                awaitingItemText = false
                listDepth = isClosing ? max(0, listDepth - 1) : listDepth + 1
                startLine(&result)
                // the outermost list is its own paragraph
                if listDepth == (isClosing ? 0 : 1) {
                    result.append("\n")
                }
            case "li":
                if !isClosing {
                    startLine(&result)
                    result.append(String(repeating: listIndent, count: max(0, listDepth - 1)))
                    result.append(listBullet)
                }
                awaitingItemText = !isClosing
            case "a" where keepLinks:
                if isClosing {
                    if let href = linkHref {
                        result.append("](\(href))")
                        linkHref = nil
                    }
                } else if let href = hrefValue(in: tag), !href.isEmpty {
                    linkHref = href
                    result.append("[")
                }
            default:
                break
            }
        }

        closeSpans(&openSpans, from: 0, in: &result)
        if linkHref != nil {
            result.append("]")
        }
        return tidy(result)
    }

    /// U+2028: a line break within the paragraph, which is what `<br>` is to a list item.
    private static let lineSeparator: Character = "\u{2028}"
    private static let blockTags: Set<String> = ["li", "ul", "ol", "p", "div", "h1", "h2", "h3", "h4", "h5", "h6"]

    private enum InlineStyle {
        case code, bold, italic, strikethrough

        var marker: String {
            switch self {
            case .code: "`"
            case .bold: "**"
            case .italic: "*"
            case .strikethrough: "~~"
            }
        }

        var isCode: Bool { self == .code }
    }

    private static let inlineStyles: [String: InlineStyle] = [
        "code": .code, "kbd": .code, "tt": .code, "samp": .code,
        "strong": .bold, "b": .bold,
        "em": .italic, "i": .italic,
        "s": .strikethrough, "strike": .strikethrough, "del": .strikethrough
    ]

    /// `offset` is where the opening marker starts, in UTF-8.
    private struct OpenSpan {
        let style: InlineStyle
        let offset: Int
    }

    /// Closes `spans[index...]`, innermost first, so the outer offsets stay valid.
    private static func closeSpans(_ spans: inout [OpenSpan], from index: Int, in result: inout String) {
        while spans.count > index {
            closeSpan(spans.removeLast(), in: &result)
        }
    }

    private static func closeSpan(_ span: OpenSpan, in result: inout String) {
        let opening = result.utf8.index(result.utf8.startIndex, offsetBy: span.offset)
        let text = result[opening...].dropFirst(span.style.marker.count)
        // markdown only takes a delimiter that hugs its text
        let leading = text.prefix(while: \.isWhitespace)
        let rest = text.dropFirst(leading.count)
        let trailingCount = rest.reversed().prefix(while: \.isWhitespace).count
        let content = String(rest.dropLast(trailingCount))
            // a newline would end the paragraph, and the span with it
            .replacing("\n", with: String(lineSeparator))
        let wrapped = content.isEmpty ? "" : wrap(content, in: span.style)
        let replacement = leading + wrapped + rest.suffix(trailingCount)
        result.replaceSubrange(opening..., with: replacement)
    }

    private static func wrap(_ content: String, in style: InlineStyle) -> String {
        guard style.isCode else {
            return style.marker + content + style.marker
        }
        // longer than any backtick run inside, so those stay text
        let longestRun = content.split { $0 != "`" }.map(\.count).max() ?? 0
        let fence = String(repeating: "`", count: longestRun + 1)
        let padding = longestRun > 0 ? " " : ""
        return fence + padding + content + padding + fence
    }

    private static func trimTrailingSpaces(_ result: inout String) {
        while let last = result.last, last == " " || last == "\t" || last == lineSeparator {
            result.removeLast()
        }
    }

    /// Breaks the line unless it already is broken, dropping the collapsed whitespace that ends it.
    private static func startLine(_ result: inout String) {
        trimTrailingSpaces(&result)
        if !result.isEmpty, !result.hasSuffix("\n") {
            result.append("\n")
        }
    }

    /// Entities are decoded last: doing it earlier would turn an escaped `&lt;p&gt;` into a tag.
    private static func tidy(_ text: String) -> String? {
        var result = text
        for (entity, character) in [
            ("&nbsp;", "\u{00A0}"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&hellip;", "…"), ("&mdash;", "—"), ("&ndash;", "–"),
            // last, so a double-escaped entity ("&amp;lt;") decodes to text rather than markup
            ("&amp;", "&")
        ] {
            result = result.replacing(entity, with: character)
        }
        result = decodeNumericEntities(result)

        // the feed's own indentation, which is markup rather than content.
        let markupIndent = CharacterSet(charactersIn: " \t")
        let lines = result.split(separator: "\n", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: markupIndent)
        }
        result = lines.joined(separator: "\n").replacingMatches(of: blankLinesRegex, with: "\n\n")
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// `&#8217;` and friends: show notes are full of them, and left alone they read as the raw entity in the middle
    /// of a word.
    private static func decodeNumericEntities(_ text: String) -> String {
        guard text.contains("&#"), let regex = numericEntityRegex else {
            return text
        }
        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let digitsRange = Range(match.range(at: 2), in: result),
                  let markerRange = Range(match.range(at: 1), in: result) else {
                continue
            }
            let radix = result[markerRange].isEmpty ? 10 : 16
            guard let value = UInt32(result[digitsRange], radix: radix),
                  let scalar = Unicode.Scalar(value) else {
                continue
            }
            result.replaceSubrange(range, with: String(Character(scalar)))
        }
        return result
    }

    private static let numericEntityRegex = try? NSRegularExpression(pattern: #"&#(x?)([0-9a-fA-F]+);"#)
    private static let hrefRegex = try? NSRegularExpression(
        pattern: "href\\s*=\\s*[\"\']([^\"\']*)[\"\']",
        options: [.caseInsensitive]
    )
    private static let blankLinesRegex = try? NSRegularExpression(pattern: #"\n{3,}"#)

    /// The `href` value in a raw tag body, single or double quoted.
    private static func hrefValue(in tag: String) -> String? {
        guard let regex = hrefRegex else {
            return nil
        }
        let range = NSRange(tag.startIndex..., in: tag)
        guard let match = regex.firstMatch(in: tag, range: range),
              let valueRange = Range(match.range(at: 1), in: tag) else {
            return nil
        }
        return String(tag[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    func replacingMatches(of regex: NSRegularExpression?, with replacement: String) -> String {
        guard let regex else {
            return self
        }
        return regex.stringByReplacingMatches(
            in: self,
            range: NSRange(startIndex..., in: self),
            withTemplate: replacement
        )
    }
}
