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
        formatter.allowedUnits = [.hour, .minute, .second]
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
}
