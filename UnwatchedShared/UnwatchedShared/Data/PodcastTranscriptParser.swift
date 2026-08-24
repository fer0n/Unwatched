//
//  PodcastTranscriptParser.swift
//  UnwatchedShared
//

import Foundation
import OSLog

/// The transcript formats Podcasting 2.0 feeds point `<podcast:transcript>` at, ranked by how much of one survives
/// the parse.
public enum PodcastTranscriptFormat: Sendable {
    /// The Podcasting 2.0 JSON transcript: timed segments, optionally with speakers.
    case json
    /// WebVTT and SubRip both cue the same way; only the decimal separator and the cue numbers differ, so one parser
    /// reads both.
    case webVTT
    case subRip

    static func from(mimeType: String?) -> PodcastTranscriptFormat? {
        switch mimeType?.lowercased() {
        case "application/json": return .json
        case "text/vtt": return .webVTT
        case "application/srt", "application/x-subrip", "text/srt": return .subRip
        default: return nil
        }
    }

    /// What the feed claims and what the host serves don't always agree, so the bytes get the final say.
    static func sniff(_ data: Data) -> PodcastTranscriptFormat? {
        let head = String(decoding: data.prefix(1024), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if head.hasPrefix("WEBVTT") { return .webVTT }
        if head.hasPrefix("{") { return .json }
        if head.contains("-->") { return .subRip }
        return nil
    }

    /// Preference order when an episode offers several transcripts.
    var rank: Int {
        switch self {
        case .json: return 3
        case .webVTT: return 2
        case .subRip: return 1
        }
    }
}

/// What reading an episode's published transcript came to.
public enum PodcastTranscriptLookup: Sendable {
    case found([TranscriptEntry])
    /// The feed was read and the episode lists no transcript this app can use.
    case notPublished
    /// The feed or the transcript file couldn't be fetched — say nothing about the episode.
    case unreachable
}

/// One `<podcast:transcript>` element.
public struct PodcastTranscriptSource: Sendable, Equatable {
    public let url: URL
    public let format: PodcastTranscriptFormat?
    public let language: String?

    public init(url: URL, format: PodcastTranscriptFormat?, language: String?) {
        self.url = url
        self.format = format
        self.language = language
    }

    /// The transcript to fetch out of everything an episode lists: the reader's language first — a show that
    /// publishes translations lists them all — then the richest format.
    public static func best(from sources: [PodcastTranscriptSource]) -> PodcastTranscriptSource? {
        let usable = sources.filter { $0.format != nil }
        guard !usable.isEmpty else { return nil }

        let preferred = Locale.current.language.languageCode?.identifier.lowercased()
        let matching = usable.filter { source in
            guard let preferred, let language = source.language?.lowercased() else { return false }
            return language == preferred || language.hasPrefix(preferred + "-")
        }
        let candidates = matching.isEmpty ? usable : matching
        return candidates.max { ($0.format?.rank ?? 0) < ($1.format?.rank ?? 0) }
    }
}

/// Turns a fetched transcript document into the same `TranscriptEntry` list the YouTube caption parser produces, so
/// the transcript view can't tell where a transcript came from.
public enum PodcastTranscriptParser {
    public static func parse(_ data: Data, format: PodcastTranscriptFormat?) -> [TranscriptEntry] {
        guard let format = format ?? PodcastTranscriptFormat.sniff(data) else {
            Log.info("podcast transcript in an unrecognized format")
            return []
        }
        switch format {
        case .json: return parseJson(data)
        case .webVTT, .subRip: return parseCues(data)
        }
    }

    // MARK: - JSON

    private struct Document: Decodable {
        let segments: [Segment]

        struct Segment: Decodable {
            let startTime: Double?
            let endTime: Double?
            let body: String?
            let speaker: String?
        }
    }

    /// The JSON format's segments are usually single words, which would make for an unreadable
    /// transcript list — they're joined back into sentences here, and split wherever the speaker
    /// changes so a dialogue stays attributable.
    private static func parseJson(_ data: Data) -> [TranscriptEntry] {
        guard let document = try? JSONDecoder().decode(Document.self, from: data) else {
            Log.warning("podcast transcript JSON could not be decoded")
            return []
        }

        var entries = [TranscriptEntry]()
        var words = [String]()
        var start: Double?
        var end: Double?
        var speaker: String?

        func flush() {
            guard let start, let end, !words.isEmpty else { return }
            let text = words.joined(separator: " ")
            entries.append(
                TranscriptEntry(
                    start: start,
                    duration: max(0, end - start),
                    text: speaker.map { "\($0): \(text)" } ?? text
                )
            )
            words = []
        }

        for segment in document.segments {
            let body = segment.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !body.isEmpty, let segmentStart = segment.startTime else { continue }

            if segment.speaker != speaker {
                flush()
                speaker = segment.speaker
                start = nil
            }
            if start == nil {
                start = segmentStart
            }
            words.append(body)
            end = segment.endTime ?? segmentStart

            if body.hasSuffix(".") || body.hasSuffix("?") || body.hasSuffix("!") {
                flush()
                start = nil
            }
        }
        flush()
        return entries
    }

    // MARK: - WebVTT / SubRip

    private static func parseCues(_ data: Data) -> [TranscriptEntry] {
        let text = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var entries = [TranscriptEntry]()
        for block in text.components(separatedBy: "\n\n") {
            var lines = block.split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
            // WEBVTT headers, NOTE blocks and STYLE blocks aren't cues
            guard !lines.isEmpty, !lines[0].hasPrefix("WEBVTT"),
                  !lines[0].hasPrefix("NOTE"), !lines[0].hasPrefix("STYLE") else { continue }

            // SubRip numbers its cues; WebVTT may label them
            if !lines[0].contains("-->") {
                lines.removeFirst()
            }
            guard let timing = lines.first, timing.contains("-->") else { continue }
            guard let (start, end) = parseTiming(timing) else { continue }

            let body = lines.dropFirst()
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let cleaned = strippingTags(body)
            guard !cleaned.isEmpty else { continue }

            entries.append(
                TranscriptEntry(start: start, duration: max(0, end - start), text: cleaned)
            )
        }
        return entries
    }

    /// `00:00:12.500 --> 00:00:15.000` — the hour is optional, and SubRip separates the milliseconds with a comma.
    private static func parseTiming(_ line: String) -> (Double, Double)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2,
              let start = parseTimestamp(parts[0]),
              let end = parseTimestamp(parts[1].components(separatedBy: .whitespaces).first { !$0.isEmpty } ?? "")
        else { return nil }
        return (start, end)
    }

    static func parseTimestamp(_ value: String) -> Double? {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty else { return nil }

        let components = trimmed.split(separator: ":").map(String.init)
        guard components.count <= 3 else { return nil }

        var seconds: Double = 0
        for component in components {
            guard let value = Double(component) else { return nil }
            seconds = seconds * 60 + value
        }
        return seconds
    }

    /// VTT cues carry inline markup (`<v Speaker>`, `<i>`, karaoke timestamps) that has no place in a plain
    /// transcript line.
    private static func strippingTags(_ text: String) -> String {
        var result = ""
        var depth = 0
        for character in text {
            if character == "<" {
                depth += 1
            } else if character == ">" {
                depth = max(0, depth - 1)
            } else if depth == 0 {
                result.append(character)
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
