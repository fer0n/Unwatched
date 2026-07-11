//
//  String.swift
//  UnwatchedShared
//

import Foundation
import OSLog

public extension String {
    var bool: Bool? {
        UserDefaults.standard.value(forKey: self) as? Bool
    }

    func matching(regex: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: regex) else { return nil }
        let range = NSRange(location: 0, length: self.utf16.count)
        if let match = regex.firstMatch(in: self, options: [], range: range) {
            if match.numberOfRanges > 1, let matchRange = Range(match.range(at: 1), in: self) {
                return String(self[matchRange])
            } else {
                return "" // Return empty string if there's a match but no capture group
            }
        }
        return nil
    }

    func matchingMultiple(regex: String) -> [String]? {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            let result = results.compactMap {
                if let range = Range($0.range, in: self) {
                    return String(self[range])
                }
                return nil
            }
            return result
        } catch let error {
            Log.error("invalid regex: \(error.localizedDescription)")
            return nil
        }
    }

    func extractURLAndRest() -> (String, URL?)? {
        let pattern = #"^(.*?)\s*(?:[–,|\(-:\s])*(https?:\/\/[^\s))]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(self.startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: range),
              let titleRange = Range(match.range(at: 1), in: self),
              let urlRange = Range(match.range(at: 2), in: self) else { return nil }

        let title = String(self[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = String(self[urlRange])
        let url = URL(string: urlString)
        return (title, url)
    }
}
