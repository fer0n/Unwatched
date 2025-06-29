import Foundation

public extension Double {
    var formattedSecondsColon: String {
        // e.g. 4:20 or 1:02:03
        if self >= 3600 {
            Duration.seconds(self).formatted(.time(pattern: .hourMinuteSecond))
        } else {
            Duration.seconds(self).formatted(.time(pattern: .minuteSecond))
        }
    }
}
