//
//  Date.swift
//  Unwatched
//

import Foundation
import SwiftUI

extension Date {
    private static let formatter: DateFormatter = {
        return DateFormatter()
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var formatted: String {
        let calendar = Calendar.current
        let formatter = Date.formatter

        if calendar.isDateInToday(self) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: self)
        } else if calendar.isDateInLastWeek(self) {
            formatter.dateFormat = "EEE d"
            return formatter.string(from: self).uppercased()
        } else if calendar.isDateInLastSixMonths(self) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self).uppercased()
        } else {
            formatter.dateFormat = "MMM d yyyy"
            return formatter.string(from: self).uppercased()
        }
    }

    var formattedExtensive: String {
        let calendar = Calendar.current
        let formatter = Date.formatter

        if calendar.isDateInToday(self) {
            formatter.dateFormat = "HH:mm"
            let time = formatter.string(from: self)
            return String(localized: "Today, \(time)")
        } else if calendar.isDateInYesterday(self) {
            formatter.dateFormat = "HH:mm"
            let time = formatter.string(from: self)
            return String(localized: "Yesterday, \(time)")
        } else if calendar.isDateInLastWeek(self) {
            formatter.dateFormat = "EEE d, HH:mm"
            return formatter.string(from: self).uppercased()
        } else if calendar.isDateInLastSixMonths(self) {
            formatter.dateFormat = "MMM d, HH:mm"
            return formatter.string(from: self).uppercased()
        } else {
            formatter.dateFormat = "MMM d yyyy, HH:mm"
            return formatter.string(from: self).uppercased()
        }
    }

    var formattedToday: String {
        let calendar = Calendar.current
        let formatter = Date.formatter

        if calendar.isDateInToday(self) {
            return String(localized: "Today")
        } else if calendar.isDateInLastWeek(self) {
            formatter.dateFormat = "EEE d"
            return formatter.string(from: self).uppercased()
        } else if calendar.isDateInLastSixMonths(self) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self).uppercased()
        } else {
            formatter.dateFormat = "MMM d yyyy"
            return formatter.string(from: self).uppercased()
        }
    }

    var formattedRelative: String {
        self.formatted(.relative(presentation: .numeric, unitsStyle: .narrow))
    }

    var formattedRelativeVerbatim: String {
        Date.relativeFormatter.localizedString(for: self, relativeTo: Date.now)
    }

    static func parseYtOfflineDate(_ dateString: String) -> Date? {
        let locales = ["en_US", "de_DE"]
        let dateFormats = [
            "MMMM d 'at' h:mm a",      // "January 22 at 8:15 PM"
            "d MMMM 'at' HH:mm",       // "8 May at 8:15 PM"
            "d. MMMM 'um' HH:mm"       // "22. Januar um 20:15"
        ]

        // Get current date components to fill in missing parts
        let currentDate = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentDate)

        for locale in locales {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: locale)
            dateFormatter.defaultDate = currentDate  // This sets default values for unspecified components

            for format in dateFormats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateString) {
                    // Ensure the year is set to current year if not specified
                    let components = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
                    if let finalDate = calendar.date(from: DateComponents(
                        year: currentYear,
                        month: components.month,
                        day: components.day,
                        hour: components.hour,
                        minute: components.minute
                    )) {
                        return finalDate
                    }
                    return date
                }
            }
        }

        return nil
    }

    /// Returns tomorrow at noon
    static var tomorrow: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date.now)

        guard var day = components.day else {
            return Date.now.addingTimeInterval(24 * 60 * 60)
        }

        // Add one day
        day += 1
        components.day = day

        // Set to noon
        components.hour = 12
        components.minute = 0
        components.second = 0

        return calendar.date(from: components) ?? Date.now.addingTimeInterval(24 * 60 * 60)
    }
}

extension Calendar {
    func isDateInLastDay(_ date: Date) -> Bool {
        let currentDate = Date()
        let oneDayAgo = self.date(byAdding: .day, value: -1, to: currentDate)!
        return date >= oneDayAgo && date < currentDate
    }

    func isDateInLastWeek(_ date: Date) -> Bool {
        let currentDate = Date()
        let oneWeekAgo = self.date(byAdding: .weekOfYear, value: -1, to: currentDate)!
        return date >= oneWeekAgo && date < currentDate
    }

    func isDateInLastSixMonths(_ date: Date) -> Bool {
        let currentDate = Date()
        let sixMonthsAgo = self.date(byAdding: .month, value: -6, to: currentDate)!
        return date >= sixMonthsAgo && date < currentDate
    }

    func isDateInLastYear(_ date: Date) -> Bool {
        let currentDate = Date()
        let oneYearAgo = self.date(byAdding: .year, value: -1, to: currentDate)!
        return date >= oneYearAgo && date < currentDate
    }
}

#Preview {
    Group {
        Text(Date.now.formattedExtensive)
        Text(Date.now.addingTimeInterval(-60 * 60 * 24).formattedExtensive)
        Text(Date.now.addingTimeInterval(-60 * 60 * 24 * 7).formattedExtensive)
        Text(Date.now.addingTimeInterval(-60 * 60 * 24 * 365 * 2).formattedExtensive)
    }
}
