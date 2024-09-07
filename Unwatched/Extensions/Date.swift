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
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [
                .second,
                .minute,
                .hour,
                .day,
                .year
            ],
            from: self,
            to: Date()
        )

        if let years = components.year, years > 0 {
            return "\(years)y"
        } else if let days = components.day, days > 0 {
            return "\(days)d"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(components.second ?? 0)s"
        }
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
