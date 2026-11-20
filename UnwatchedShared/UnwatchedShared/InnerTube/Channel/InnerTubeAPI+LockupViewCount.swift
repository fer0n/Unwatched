//
//  InnerTubeAPI+LockupViewCount.swift
//  UnwatchedShared
//

import Foundation

extension InnerTubeAPI {
    /// A lockup metadata part that is only a count ("3.3M", "1,234 views", "No views"); nil for "1.2K watching"
    static func lockupViewCount(_ text: String) -> Int? {
        let text = text.trimmingCharacters(in: .whitespaces)
        if text.caseInsensitiveCompare("No views") == .orderedSame { return 0 }
        guard let match = text.wholeMatch(of: #/(?i)(\d[\d,]*(?:\.\d+)?)\s*([KMB])?(?:\s+views?)?/#),
              let value = Double(match.1.replacingOccurrences(of: ",", with: "")) else { return nil }
        let multiplier: Double = switch match.2?.uppercased() {
        case "K": 1_000
        case "M": 1_000_000
        case "B": 1_000_000_000
        default: 1
        }
        return Int((value * multiplier).rounded())
    }
}
