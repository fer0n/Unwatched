//
//  YearReviewCalendar.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Month blocks of week rows: one column while they fit, else up to three filled row by row.
struct YearReviewCalendar: View {
    let heightBudget: CGFloat
    let opacity: (Date) -> Double
    private let months: [[[Date?]]]

    init(days: ClosedRange<Date>, heightBudget: CGFloat, opacity: @escaping (Date) -> Double) {
        self.heightBudget = heightBudget
        self.opacity = opacity
        if let cached = Self.cache[days] {
            months = cached
        } else {
            months = Self.months(in: days)
            Self.cache = [days: months]
        }
    }

    static let calendar: Calendar = {
        var calendar = YearReviewVM.calendar
        calendar.firstWeekday = Calendar.current.firstWeekday
        return calendar
    }()

    private static var cache: [ClosedRange<Date>: [[[Date?]]]] = [:]
    private static let weeksPerColumn = 16
    private static let gridWidth: CGFloat = 330
    private static let columnGap: CGFloat = 12
    private static let monthGap: CGFloat = 10

    var body: some View {
        let weekCount = months.reduce(0) { $0 + $1.count }
        let columnCount = min(3, months.count, max(1, (weekCount + Self.weeksPerColumn - 1) / Self.weeksPerColumn))
        let gridRows = stride(from: 0, to: months.count, by: columnCount).map {
            Array(months[$0..<min($0 + columnCount, months.count)])
        }
        let weekRows = gridRows.reduce(0) { $0 + ($1.map(\.count).max() ?? 0) }
        let columnWidth = (Self.gridWidth - CGFloat(columnCount - 1) * Self.columnGap) / CGFloat(columnCount)
        let rowBudget = heightBudget - CGFloat(gridRows.count) * (Self.monthGap + 16)
        let cell = max(6, min(24, columnWidth / 7 - 4, rowBudget / CGFloat(max(weekRows, 1)) - 4))
        Grid(alignment: .topLeading, horizontalSpacing: Self.columnGap, verticalSpacing: Self.monthGap) {
            GridRow {
                ForEach(0..<columnCount, id: \.self) { _ in
                    weekdayHeader(cell: cell)
                }
            }
            ForEach(gridRows.indices, id: \.self) { row in
                GridRow {
                    ForEach(gridRows[row].indices, id: \.self) { column in
                        monthBlock(gridRows[row][column], cell: cell)
                    }
                }
            }
        }
    }

    private static func months(in days: ClosedRange<Date>) -> [[[Date?]]] {
        let calendar = Self.calendar
        guard var weekStart = calendar.dateInterval(of: .weekOfYear, for: days.lowerBound)?.start else { return [] }
        var months: [[[Date?]]] = []
        while weekStart <= days.upperBound {
            let week: [Date?] = (0..<7).map { offset in
                calendar.date(byAdding: .day, value: offset, to: weekStart).flatMap { days.contains($0) ? $0 : nil }
            }
            for month in Set(week.compactMap { $0.map { calendar.component(.month, from: $0) } }).sorted() {
                let row = week.map { day in day.flatMap { calendar.component(.month, from: $0) == month ? $0 : nil } }
                if let current = months.last?.last?.lazy.compactMap({ $0 }).first,
                   calendar.component(.month, from: current) == month {
                    months[months.count - 1].append(row)
                } else {
                    months.append([row])
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = next
        }
        return months
    }

    private func weekdayHeader(cell: CGFloat) -> some View {
        let symbols = Self.weekdaySymbols
        return HStack(spacing: 4) {
            ForEach(symbols.indices, id: \.self) { index in
                Text(symbols[index])
                    .font(.system(size: min(11, cell)))
                    .opacity(0.6)
                    .frame(width: cell)
            }
        }
    }

    private func monthBlock(_ rows: [[Date?]], cell: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let date = rows.lazy.flatMap({ $0 }).compactMap({ $0 }).first {
                Text(date, format: YearReviewFormat.gmt(.dateTime.month(.abbreviated)))
                    .font(.caption2.weight(.semibold))
                    .opacity(0.75)
            }
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(rows[row].indices, id: \.self) { column in
                        if let day = rows[row][column] {
                            RoundedRectangle(cornerRadius: cell * 0.25)
                                .fill(.white.opacity(opacity(day)))
                                .frame(width: cell, height: cell)
                        } else {
                            Color.clear.frame(width: cell, height: cell)
                        }
                    }
                }
            }
        }
    }

    private static var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let offset = Calendar.current.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }
}
