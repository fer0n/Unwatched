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
    var formattedSeconds: String {
        let units: Set<Duration.UnitsFormatStyle.Unit> = {
            if self >= 3600 {
                return [.hours, .minutes]
            } else if self >= 60 {
                return [.minutes, .seconds]
            } else {
                return [.seconds]
            }
        }()
        return Duration.seconds(self).formatted(.units(allowed: units, width: .narrow))
    }

    var formatTimeMinimal: String {
        Duration
            .seconds(self)
            .formatted(
                .units(
                    allowed: [.hours, .minutes, .seconds],
                    width: .narrow,
                    maximumUnitCount: 1
                )
                .locale(Locale(identifier: "en_US_POSIX"))
            )
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
