import Foundation

public extension Double {
    func formattedSecondsColon(fuzzy: Bool = false) -> String {
        // e.g. 4:20 or 1:02:03
        let time = {
            if self >= 3600 {
                return Duration.seconds(self).formatted(.time(pattern: .hourMinuteSecond))
            } else {
                return Duration.seconds(self).formatted(.time(pattern: .minuteSecond))
            }
        }()
        return fuzzy ? (time.dropLast(1) + "-") : time
    }
}
