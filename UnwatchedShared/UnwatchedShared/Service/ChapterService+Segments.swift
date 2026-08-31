//
//  ChapterService+Segments.swift
//  UnwatchedShared
//

import Foundation

public extension ChapterService {
    /// Parses segments written as time ranges, the counterpart to `extractChapters` for everything that
    /// covers only part of a video: `00:35 - 01:20 sponsor: Squarespace`.
    ///
    /// The category and the title are both optional. A segment whose category isn't one of the words in
    /// `segmentCategories` is a plain `.chapter`: nothing here is worth skipping the video over unless it
    /// was actually named as a sponsor. The result is what SponsorBlock's own segments look like, so it
    /// goes through the same merge.
    static func extractSegments(from text: String, videoDuration: Double?) -> [SendableChapter] {
        guard let regex = try? NSRegularExpression(
            pattern: #"^\h*\W*?(\d+(?:\:\d+)+(?:\.\d+)?)\h*(?:[\-–—]+|to\b)\h*(\d+(?:\:\d+)+(?:\.\d+)?)\h*(.*)$"#,
            options: [.anchorsMatchLines]
        ) else {
            Log.error("extractSegments: could not create regex")
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var segments = [SendableChapter]()

        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match,
                  let startRange = Range(match.range(at: 1), in: text),
                  let endRange = Range(match.range(at: 2), in: text),
                  let startTime = timeToSeconds(String(text[startRange])),
                  let endTime = timeToSeconds(String(text[endRange])) else {
                return
            }

            var rest = ""
            if let restRange = Range(match.range(at: 3), in: text) {
                rest = String(text[restRange])
            }
            let (category, title) = splitCategory(from: rest)

            if let segment = makeSegment(
                startTime: startTime,
                endTime: endTime,
                category: category,
                title: title,
                videoDuration: videoDuration
            ) {
                segments.append(segment)
            }
        }

        return segments.sorted { $0.startTime < $1.startTime }
    }

    /// `nil` for a range that can't describe anything: reversed, empty, or past the end of the video.
    private static func makeSegment(
        startTime: Double,
        endTime: Double,
        category: ChapterCategory,
        title: String?,
        videoDuration: Double?
    ) -> SendableChapter? {
        var endTime = endTime
        if let videoDuration {
            guard startTime < videoDuration else { return nil }
            endTime = min(endTime, videoDuration)
        }
        guard endTime - startTime > Const.chapterTimeTolerance else { return nil }

        return SendableChapter(
            title: title,
            startTime: startTime,
            endTime: endTime,
            duration: endTime - startTime,
            category: category
        )
    }

    /// Reads the category off the front of what follows the times, longest match first, so
    /// `music offtopic: outro theme` doesn't come back as the two-word title of a `.musicOfftopic`.
    static func splitCategory(from rest: String) -> (ChapterCategory, String?) {
        let rest = trimSeparators(rest)
        guard !rest.isEmpty else { return (.chapter, nil) }

        if let category = segmentCategories[normalizedCategory(rest)] {
            return (category, nil)
        }

        let words = rest.split(separator: " ", omittingEmptySubsequences: true)
        for count in stride(from: min(2, words.count), through: 1, by: -1) {
            let candidate = words.prefix(count).joined(separator: " ")
            guard let category = segmentCategories[normalizedCategory(candidate)] else { continue }
            let title = trimSeparators(words.dropFirst(count).joined(separator: " "))
            return (category, title.isEmpty ? nil : title)
        }

        return (.chapter, rest)
    }

    private static func trimSeparators(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: " \t:|-–—»>·•,")
            .union(.whitespacesAndNewlines))
    }

    /// Case, spacing and punctuation are whatever the text happened to use: `music_offtopic`,
    /// `Music Offtopic` and `music-offtopic` are the same category.
    private static func normalizedCategory(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// SponsorBlock's category names, plus the words a description or a language model tends to
    /// use for them instead.
    private static var segmentCategories: [String: ChapterCategory] {
        [
            "sponsor": .sponsor,
            "sponsored": .sponsor,
            "sponsorship": .sponsor,
            "ad": .sponsor,
            "ads": .sponsor,
            "advert": .sponsor,
            "advertisement": .sponsor,
            "selfpromo": .selfpromo,
            "selfpromotion": .selfpromo,
            "unpaidselfpromotion": .selfpromo,
            "promo": .selfpromo,
            "promotion": .selfpromo,
            "interaction": .interaction,
            "subscriptionreminder": .interaction,
            "reminder": .interaction,
            "intro": .intro,
            "intermission": .intro,
            "outro": .outro,
            "endcards": .outro,
            "credits": .outro,
            "preview": .preview,
            "recap": .preview,
            "filler": .filler,
            "tangent": .filler,
            "musicofftopic": .musicOfftopic,
            "offtopic": .musicOfftopic,
            "nonmusic": .musicOfftopic,
            "chapter": .chapter
        ]
    }
}
