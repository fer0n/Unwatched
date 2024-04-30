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

    static let iso8601Formatter: ISO8601DateFormatter = {
        return ISO8601DateFormatter()
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
        Text(Date.now.formatted)
        Text(Date.now.addingTimeInterval(-60 * 60 * 24).formatted)
        Text(Date.now.addingTimeInterval(-60 * 60 * 24 * 7).formatted)
        Text(Date.now.addingTimeInterval(-60 * 60 * 24 * 365 * 2).formatted)
    }
}
