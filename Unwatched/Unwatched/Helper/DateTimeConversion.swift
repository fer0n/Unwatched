//
//  DateTimeConversion.swift
//  Unwatched
//

import Foundation

// converts "PT3M20S" to seconds
// PT3H2M27S
func parseDurationToSeconds(_ duration: String) -> Double? {
    // Check if the string starts with "PT" and ends with "S"
    guard duration.hasPrefix("PT"), duration.hasSuffix("S") else {
        return nil
    }

    // Remove "PT" and "S" from the string
    var durationString = duration.replacingOccurrences(of: "PT", with: "")

    var totalSeconds: Double = 0

    // Extract days if present
    if let dayRange = durationString.range(of: "D") {
        if let days = Double(durationString[..<dayRange.lowerBound]) {
            totalSeconds += days * 86400 // 1 day = 86400 seconds
            durationString.removeSubrange(..<dayRange.upperBound)
        }
    }

    // Extract hours if present
    if let hourRange = durationString.range(of: "H") {
        if let hours = Double(durationString[..<hourRange.lowerBound]) {
            totalSeconds += hours * 3600
            durationString.removeSubrange(..<hourRange.upperBound)
        }
    }

    // Extract minutes if present
    if let minuteRange = durationString.range(of: "M") {
        if let minutes = Double(durationString[..<minuteRange.lowerBound]) {
            totalSeconds += minutes * 60
            durationString.removeSubrange(..<minuteRange.upperBound)
        }
    }

    // Extract seconds if present
    if let secondRange = durationString.range(of: "S") {
        if let seconds = Double(durationString[..<secondRange.lowerBound]) {
            totalSeconds += seconds
        }
    }

    return totalSeconds
}

func formatDurationFromSeconds(_ seconds: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .positional

    if let formattedDuration = formatter.string(from: seconds) {
        let components = formattedDuration.split(separator: ":")
        if components.count == 1 {
            return "\(formattedDuration)s"
        } else {
            return formattedDuration
        }
    } else {
        return ""
    }
}
