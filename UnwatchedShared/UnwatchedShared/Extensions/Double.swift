import Foundation

public extension Double {
    var formattedSecondsColon: String? {
        // e.g. 4:20 or 1:02:03
        let formatter = DateComponentsFormatter()
        if self >= 3600 {
            formatter.allowedUnits = [.hour, .minute, .second]
        } else {
            formatter.allowedUnits = [.minute, .second]
        }
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: TimeInterval(self))
    }
}
