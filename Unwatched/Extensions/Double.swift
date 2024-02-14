import Foundation

extension Double {
    // enable an optional value and parse it as a doouble here, otherwise nil
    init?(_ optionalString: String?) {
        guard let string = optionalString else { return nil }
        self.init(string)
    }
}

extension Double {
    var formattedSeconds: String? {
        let formatter = DateComponentsFormatter()
        if self >= 3600 { // If self is greater than or equal to 3600 seconds (1 hour)
            formatter.allowedUnits = [.hour, .minute]
        } else if self >= 60 { // If self is greater than or equal to 60 seconds (1 minute)
            formatter.allowedUnits = [.minute, .second]
        } else {
            formatter.allowedUnits = [.second]
        }
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(self))
    }

    func getFormattedSeconds(for allowedUnits: NSCalendar.Unit) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = self < 60 ? [.second] : allowedUnits
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(self))
    }

    var formatTimeMinimal: String? {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        formatter.maximumUnitCount = 1
        formatter.calendar?.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: TimeInterval(self))
    }
}
