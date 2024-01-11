import Foundation

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
            if let matchRange = Range(match.range(at: 1), in: self) {
                return String(self[matchRange])
            }
        }
        return nil
    }
}
