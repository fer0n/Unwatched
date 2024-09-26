import Foundation
import UnwatchedShared

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

    static private let formattedSecondsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }()

    func getFormattedSeconds(for allowedUnits: NSCalendar.Unit) -> String? {
        Double.formattedSecondsFormatter.allowedUnits = self < 60 ? [.second] : allowedUnits
        return Double.formattedSecondsFormatter.string(from: TimeInterval(self))
    }

    static private let timeMinimalFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        formatter.maximumUnitCount = 1
        formatter.calendar?.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    var formatTimeMinimal: String? {
        Double.timeMinimalFormatter.string(from: TimeInterval(self))
    }
}

extension Double {
    /// Allow a small discrepancy between the given and usual aspect ratios
    var cleanedAspectRatio: Double {
        let buffer = Const.aspectRatioTolerance
        for aspectRatio in Const.videoAspectRatios where abs(aspectRatio - self) < buffer {
            return aspectRatio
        }
        return self
    }
}
