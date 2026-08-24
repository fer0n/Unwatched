//
//  PodcastShowNotes.swift
//  UnwatchedShared
//

import Foundation

/// Turns a show's HTML notes into the markdown-ish text the description views render.
enum PodcastShowNotes {
    /// Podcast show notes are HTML, and for most shows they *are* the episode: a nested list of links.
    static func plainText(_ html: String?, keepLinks: Bool = true) -> String? {
        guard let html, !html.isEmpty else { return nil }

        var result = ""
        var listDepth = 0
        var linkHref: String?
        var index = html.startIndex

        while index < html.endIndex {
            let character = html[index]
            guard character == "<", let close = html[index...].firstIndex(of: ">") else {
                // inside a link the brackets are markdown syntax, so they can't stay as they are
                if linkHref != nil, character == "[" || character == "]" {
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

            switch name {
            case "br":
                result.append("\n")
            case "p", "div", "h1", "h2", "h3", "h4", "h5", "h6":
                result.append("\n")
            case "ul", "ol":
                listDepth = isClosing ? max(0, listDepth - 1) : listDepth + 1
                result.append("\n")
            case "li":
                if !isClosing {
                    // non-breaking: four plain spaces would make markdown read the line as code
                    result.append("\n" + String(repeating: "\u{00A0}\u{00A0}", count: max(0, listDepth - 1)))
                    result.append("\u{2022} ")
                }
            case "a" where keepLinks:
                if isClosing {
                    if let href = linkHref {
                        result.append("](\(href))")
                        linkHref = nil
                    }
                } else if let href = attribute("href", in: tag), !href.isEmpty {
                    linkHref = href
                    result.append("[")
                }
            default:
                break
            }
        }

        if linkHref != nil {
            result.append("]")
        }
        return tidy(result)
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
        result = lines.joined(separator: "\n").replacingMatches(of: #"\n{3,}"#, with: "\n\n")
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// `&#8217;` and friends: show notes are full of them, and left alone they read as the raw entity in the middle
    /// of a word.
    private static func decodeNumericEntities(_ text: String) -> String {
        guard text.contains("&#"),
              let regex = try? NSRegularExpression(pattern: #"&#(x?)([0-9a-fA-F]+);"#) else {
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

    /// The value of `name` in a raw tag body, single or double quoted.
    private static func attribute(_ name: String, in tag: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: "\(name)\\s*=\\s*[\"\']([^\"\']*)[\"\']",
            options: [.caseInsensitive]
        ) else {
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
    func replacingMatches(of pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return self
        }
        return regex.stringByReplacingMatches(
            in: self,
            range: NSRange(startIndex..., in: self),
            withTemplate: replacement
        )
    }
}
