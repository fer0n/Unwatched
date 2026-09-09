//
//  TranscriptMatcher.swift
//  UnwatchedShared
//

import Foundation

/// Finds where a freshly transcribed window of audio sits inside a published transcript.
///
/// Words are indexed as overlapping n-grams; a candidate window votes for the shift that would
/// line it up, and the shift with the most votes wins. The vote count doubles as the confidence:
/// audio that isn't in the transcript at all scores at or near zero, so `minimumVotes` separates
/// "found it here" from "not in this transcript".
public struct TranscriptMatcher: Sendable {
    public struct Match: Sendable, Equatable {
        public let time: Double
        public let votes: Int
        /// Transcript time of the first and last word that voted for this match. A window
        /// straddling the edge of an inserted segment only matches its covered part, so the
        /// span says where the transcript's coverage stops.
        public let spanStart: Double
        public let spanEnd: Double
    }

    public static let minimumVotes = 4

    private static let ngramLength = 4
    /// An n-gram this common is boilerplate ("und das ist die") and votes for everything.
    private static let maximumPostings = 6

    private let times: [Double]
    private let index: [String: [Int]]

    public init(entries: [TranscriptEntry]) {
        var times = [Double]()
        var words = [String]()
        for entry in entries {
            let entryWords = Self.normalize(entry.text)
            guard !entryWords.isEmpty else { continue }
            let step = entry.duration / Double(entryWords.count)
            for (offset, word) in entryWords.enumerated() {
                words.append(word)
                times.append(entry.start + step * Double(offset))
            }
        }
        self.times = times

        var index = [String: [Int]]()
        for start in 0..<max(0, words.count - Self.ngramLength + 1) {
            index[Self.key(words, start), default: []].append(start)
        }
        self.index = index
    }

    public var isEmpty: Bool { times.isEmpty }

    /// Where `text` was spoken according to the transcript, or nil when it can't be placed.
    public func locate(_ text: String) -> Match? {
        let words = Self.normalize(text)
        guard words.count >= Self.ngramLength, !times.isEmpty else { return nil }

        var candidates = [(start: Int, postings: [Int])]()
        var votes = [Int: Int]()
        for start in 0...(words.count - Self.ngramLength) {
            guard let postings = index[Self.key(words, start)],
                  postings.count <= Self.maximumPostings else { continue }
            candidates.append((start, postings))
            for posting in postings {
                votes[posting - start, default: 0] += 1
            }
        }

        guard let best = votes.max(by: { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        }), best.key >= 0, best.key < times.count else { return nil }

        let wordIndex = best.key
        var lowest = Int.max
        var highest = Int.min
        for candidate in candidates where candidate.postings.contains(wordIndex + candidate.start) {
            lowest = min(lowest, wordIndex + candidate.start)
            highest = max(highest, wordIndex + candidate.start + Self.ngramLength - 1)
        }
        guard lowest <= highest else { return nil }

        return Match(
            time: times[wordIndex],
            votes: best.value,
            spanStart: times[min(lowest, times.count - 1)],
            spanEnd: times[min(highest, times.count - 1)]
        )
    }

    private static func key(_ words: [String], _ start: Int) -> String {
        words[start..<(start + ngramLength)].joined(separator: " ")
    }

    /// Lowercased, transliterated and stripped of punctuation, so the speech model's spelling of a
    /// word still matches the publisher's.
    static func normalize(_ text: String) -> [String] {
        var folded = text.lowercased()
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ß", with: "ss")
        folded = folded.folding(options: [.diacriticInsensitive], locale: nil)

        var words = [String]()
        var current = ""
        for character in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(character) {
                current.unicodeScalars.append(character)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            words.append(current)
        }
        return words
    }
}
