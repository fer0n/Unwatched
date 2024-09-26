import Foundation
import OSLog

extension String {
    var isValidURL: Bool {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        if let match = detector.firstMatch(
            in: self,
            options: [],
            range: NSRange(location: 0, length: self.utf16.count)) {
            // it is a link, if the match covers the whole string
            return match.range.length == self.utf16.count
        } else {
            return false
        }
    }
}

extension String {
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
            Logger.log.error("invalid regex: \(error.localizedDescription)")
            return nil
        }
    }
}
