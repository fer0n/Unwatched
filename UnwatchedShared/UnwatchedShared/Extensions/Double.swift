import Foundation

public extension Double {
    var formattedSecondsColon: String {
        // e.g. 4:20 or 1:02:03
        if self >= 3600 {
            return Duration.seconds(self)
                .formatted(.time(pattern: .hourMinuteSecond))
        } else {
            return Duration.seconds(self)
                .formatted(.time(pattern: .minuteSecond))
        }
    }
    
    func getFormattedSecondsColon(_ basedOn: Double) -> String {
        // e.g. 4:20 or 1:02:03
        if basedOn >= 3600 {
            let requiresPad = basedOn >= 36000
            return Duration.seconds(self)
                .formatted(.time(pattern: .hourMinuteSecond(padHourToLength: requiresPad ? 2 : 1)))
        } else {
            let requiresPad = basedOn >= 600
            return Duration.seconds(self)
                .formatted(.time(pattern: .minuteSecond(padMinuteToLength: requiresPad ? 2 : 1)))
        }
    }
}
