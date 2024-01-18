//
//  Date.swift
//  Unwatched
//

import Foundation

extension Date {
    var formatted: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        if calendar.isDateInToday(self) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: self)
        } else if calendar.isDateInLastWeek(self) {
            formatter.dateFormat = "EEE d"
            return formatter.string(from: self).uppercased()
        } else if calendar.isDateInLastYear(self) {
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

    func isDateInLastYear(_ date: Date) -> Bool {
        let currentDate = Date()
        let oneYearAgo = self.date(byAdding: .year, value: -1, to: currentDate)!
        return date >= oneYearAgo && date < currentDate
    }
}
