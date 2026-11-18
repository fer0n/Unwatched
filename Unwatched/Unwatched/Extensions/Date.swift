//
//  Date.swift
//  Unwatched
//

import Foundation
import UnwatchedShared
import SwiftUI

extension Date {
    private static let formatter: DateFormatter = {
        return DateFormatter()
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

    /// "Starts Tue 17 Nov, 09:34"
    var formattedStart: String {
        String(localized: "Starts \(formattedStartDate)")
    }

    var formattedOverdueStart: String {
        String(localized: "Scheduled \(formattedStartDate)")
    }

    private var formattedStartDate: String {
        formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }

    var formattedRelative: String {
        self.formatted(.relative(presentation: .numeric, unitsStyle: .narrow))
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
}

extension Calendar {
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
}

#Preview {
    Group {
        Text(Date.now.formattedExtensive)
        Text(Date.now.addingTimeInterval(-60 * 60 * 24).formattedExtensive)
        Text(Date.now.addingTimeInterval(-60 * 60 * 24 * 7).formattedExtensive)
        Text(Date.now.addingTimeInterval(-60 * 60 * 24 * 365 * 2).formattedExtensive)
    }
}

extension VideoData {
    var formattedScheduledStart: String? {
        upcomingStartDate?.formattedStart ?? overdueStartDate?.formattedOverdueStart
    }
}
