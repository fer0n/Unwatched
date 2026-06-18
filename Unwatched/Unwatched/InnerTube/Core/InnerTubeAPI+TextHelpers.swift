import Foundation
import OSLog

private let tubeLog = Logger(subsystem: appSubsystem, category: "InnerTube")

// MARK: - Text extraction helpers

extension InnerTubeAPI {

    func extractText(_ dict: [String: Any]) -> String? {
        if let simple = dict["simpleText"] as? String { return simple }
        if let runs = dict["runs"] as? [[String: Any]] {
            return runs.compactMap { $0["text"] as? String }.joined()
        }
        return nil
    }

    func parseDuration(_ text: String) -> TimeInterval? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 2: return TimeInterval(parts[0] * 60 + parts[1])
        case 3: return TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
        default: return nil
        }
    }

    /// Extracts the display title from an itemSectionRenderer header dict.

    func extractSectionTitle(from header: [String: Any]) -> String? {
        let rendererKeys = [
            "tileGroupHeaderRenderer",
            "itemSectionHeaderRenderer",
            "richSectionHeaderRenderer",
            "sectionHeaderRenderer",
        ]
        for key in rendererKeys {
            if let renderer = header[key] as? [String: Any],
               let titleObj = renderer["title"] as? [String: Any],
               let text = extractText(titleObj) {
                return text
            }
        }
        return nil
    }

    /// Maps a section label ("Today", "Yesterday", …) to an approximate Date.
    func parseSectionDate(_ title: String) -> Date? {
        let cal = Calendar.current
        let now = Date.now
        let startOfToday = cal.startOfDay(for: now)
        let fmt: (Date?) -> String = { d in d.map { ISO8601DateFormatter().string(from: $0) } ?? "nil" }
        switch title.lowercased() {
        case "today":
            let d = startOfToday
            tubeLog.notice("parseSectionDate '\(title, privacy: .public)' → today (\(fmt(d), privacy: .public))")
            return d
        case "yesterday":
            let d = cal.date(byAdding: .day, value: -1, to: startOfToday)
            tubeLog.notice("parseSectionDate '\(title, privacy: .public)' → -1d (\(fmt(d), privacy: .public))")
            return d
        case "this week":
            let d = cal.date(byAdding: .day, value: -4, to: startOfToday)
            tubeLog.notice("parseSectionDate '\(title, privacy: .public)' → -4d (\(fmt(d), privacy: .public))")
            return d
        case "last week":
            let d = cal.date(byAdding: .day, value: -10, to: startOfToday)
            tubeLog.notice("parseSectionDate '\(title, privacy: .public)' → -10d (\(fmt(d), privacy: .public))")
            return d
        case "earlier this month":
            let d = cal.date(byAdding: .day, value: -15, to: startOfToday)
            tubeLog.notice("parseSectionDate '\(title, privacy: .public)' → -15d (\(fmt(d), privacy: .public))")
            return d
        case "this month":
            let d = cal.date(byAdding: .day, value: -7, to: startOfToday)
            tubeLog.notice("parseSectionDate '\(title, privacy: .public)' → -7d (\(fmt(d), privacy: .public))")
            return d
        case "last month":
            let d = cal.date(byAdding: .month, value: -1, to: startOfToday)
            tubeLog.notice("parseSectionDate '\(title, privacy: .public)' → -1mo (\(fmt(d), privacy: .public))")
            return d
        default:
            let d = parseRelativeDate(title)
            tubeLog.notice("parseSectionDate '\(title, privacy: .public)' → relativeDate fallback → \(fmt(d), privacy: .public)")
            return d
        }
    }

    /// Parses "Scheduled for 5/27/26, 4:00 PM" style strings from upcoming video tiles.
    /// Returns the scheduled future date, or nil if the format is not recognised.
    func parseScheduledDate(_ text: String) -> Date? {
        let stripped = text.replacingOccurrences(
            of: #"^Scheduled for\s+"#, with: "", options: .regularExpression)
        guard stripped != text else { return nil }   // no "Scheduled for" prefix → bail early
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d/yy, h:mm a"
        if let date = formatter.date(from: stripped) {
            tubeLog.notice("parseScheduledDate '\(text, privacy: .public)' → \(ISO8601DateFormatter().string(from: date), privacy: .public)")
            return date
        }
        tubeLog.notice("parseScheduledDate '\(text, privacy: .public)' → no match")
        return nil
    }

    func parseRelativeDate(_ text: String) -> Date? {
        let stripped = text
            .replacingOccurrences(of: #"^(Streamed|Premiered|Started)\s+"#, with: "", options: .regularExpression)
            .lowercased()
        let pattern = #"(\d+)\s+(second|minute|hour|day|week|month|year)s?\s+ago"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: stripped, range: NSRange(stripped.startIndex..., in: stripped)),
              let valueRange = Range(match.range(at: 1), in: stripped),
              let unitRange = Range(match.range(at: 2), in: stripped),
              let value = Int(stripped[valueRange])
        else {
            tubeLog.notice("parseRelativeDate '\(text, privacy: .public)' → no regex match")
            return nil
        }
        let unit = String(stripped[unitRange])
        let seconds: TimeInterval
        switch unit {
        case "second": seconds = TimeInterval(value)
        case "minute": seconds = TimeInterval(value * 60)
        case "hour":   seconds = TimeInterval(value * 3_600)
        case "day":    seconds = TimeInterval(value * 86_400)
        case "week":   seconds = TimeInterval(value * 7 * 86_400)
        case "month":  seconds = TimeInterval(value * 30 * 86_400)
        case "year":   seconds = TimeInterval(value * 365 * 86_400)
        default:       return nil
        }
        let result = Date(timeIntervalSinceNow: -seconds)
        tubeLog.notice("parseRelativeDate '\(text, privacy: .public)' → \(value, privacy: .public) \(unit, privacy: .public)(s) ago → \(ISO8601DateFormatter().string(from: result), privacy: .public)")
        return result
    }

    func extractNumber(_ text: String) -> Int? {
        // Suffix path: extract leading decimal + K/M/B multiplier (e.g. "1.5K" → 1500)
        let pattern = #"([\d,]+(?:\.\d+)?)\s*([KkMmBb])\b"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let numRange = Range(match.range(at: 1), in: text),
           let suffixRange = Range(match.range(at: 2), in: text) {
            let numStr = text[numRange].replacingOccurrences(of: ",", with: "")
            if let value = Double(numStr) {
                let suffix = text[suffixRange].uppercased()
                let multiplier: Double
                switch suffix {
                case "K": multiplier = 1_000
                case "M": multiplier = 1_000_000
                case "B": multiplier = 1_000_000_000
                default:  multiplier = 1
                }
                return Int(value * multiplier)
            }
        }
        // Plain path: strip non-digits (handles commas in "1,234 views")
        let digits = text.replacingOccurrences(of: ",", with: "")
            .components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return digits.isEmpty ? nil : Int(digits)
    }
}

// MARK: - Timestamp detection (public, used by UI layer for linkification)

/// Finds all MM:SS and HH:MM:SS timestamp patterns in `text` and returns their
/// string ranges paired with the corresponding `TimeInterval` in seconds.
/// Used by `descriptionAttributedString` and `CommentRowView` to make timestamps tappable.
public func findTimestamps(in text: String) -> [(range: Range<String.Index>, seconds: TimeInterval)] {
    // Negative look-behind/ahead ensure we don't partially match longer digit strings
    // (e.g. "12:345" should not produce a 12:34 match).
    let pattern = #"(?<!\d)(\d{1,2}:\d{2}(?::\d{2})?)(?!\d)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    var results: [(Range<String.Index>, TimeInterval)] = []
    let fullRange = NSRange(text.startIndex..., in: text)
    for match in regex.matches(in: text, range: fullRange) {
        guard let range = Range(match.range(at: 0), in: text) else { continue }
        let str = String(text[range])
        let parts = str.split(separator: ":").compactMap { Int($0) }
        let seconds: TimeInterval
        switch parts.count {
        case 2: seconds = TimeInterval(parts[0] * 60 + parts[1])
        case 3: seconds = TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
        default: continue
        }
        results.append((range, seconds))
    }
    return results
}
