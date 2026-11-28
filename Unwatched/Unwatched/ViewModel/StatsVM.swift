//
//  StatsVM.swift
//  Unwatched
//

import Foundation
import SwiftData
import UnwatchedShared
import OSLog
import SwiftUI

@Observable
final class StatsVM {
    var rawStats: [SendableWatchTimeEntry] = []
    var groupedStats: [GroupedStats] = []
    var channelImages: [String: StatsChannelImage] = [:]
    var isLoading = false
    var scope: StatsScope = .day {
        didSet {
            processStats()
        }
    }

    @MainActor
    func loadStats(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }

        await StatsService.shared.flush()?.value
        let task = Task.detached {
            let actor = StatsActor()
            return (try await actor.getStats(), try await actor.getChannelImages())
        }

        do {
            (rawStats, channelImages) = try await task.value
            processStats(showLoading: showLoading)
        } catch {
            Log.error("StatsVM: Failed to load stats: \(error)")
            if showLoading {
                isLoading = false
            }
        }
    }

    @MainActor
    func deleteStats(date: Date, channelId: String? = nil) async {
        let calendar = Calendar.current
        var startDate: Date
        var endDate: Date

        switch scope {
        case .day:
            startDate = calendar.startOfDay(for: date)
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            startDate = calendar.date(from: components) ?? date
            endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .year:
            let components = calendar.dateComponents([.year], from: date)
            startDate = calendar.date(from: components) ?? date
            endDate = calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        case .total:
            startDate = .distantPast
            endDate = .distantFuture
        }

        await StatsService.shared.flush()?.value
        let task = Task.detached {
            let actor = StatsActor()
            try await actor.deleteStats(from: startDate, to: endDate, channelId: channelId)
        }

        do {
            try await task.value
            await loadStats(showLoading: false)
        } catch {
            Log.error("StatsVM: Failed to delete stats: \(error)")
        }
    }

    func processStats(showLoading: Bool = true) {
        if showLoading {
            isLoading = true
        }
        let currentScope = scope
        let currentRawStats = rawStats

        Task.detached {
            let grouped = self.groupStats(stats: currentRawStats, scope: currentScope)
            await MainActor.run {
                withAnimation {
                    self.groupedStats = grouped
                }
                if showLoading {
                    self.isLoading = false
                }
            }
        }
    }

    private func groupStats(stats: [SendableWatchTimeEntry], scope: StatsScope) -> [GroupedStats] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let groupedDictionary = Dictionary(grouping: stats) { stat -> Date in
            switch scope {
            case .day:
                // stats.date is already normalized to GMT 00:00:00
                return calendar.startOfDay(for: stat.date)
            case .month:
                let components = calendar.dateComponents([.year, .month], from: stat.date)
                return calendar.date(from: components) ?? stat.date
            case .year:
                let components = calendar.dateComponents([.year], from: stat.date)
                return calendar.date(from: components) ?? stat.date
            case .total:
                return .distantPast
            }
        }

        let sortedDates = groupedDictionary.keys.sorted(by: >)

        return sortedDates.map { date in
            let statsForDate = groupedDictionary[date] ?? []

            // Group by channel within the period
            let channelDict = Dictionary(grouping: statsForDate, by: { $0.channelId })

            let channelStats = channelDict.map { channelId, stats -> ChannelStat in
                let totalTime = stats.reduce(0) { $0 + $1.watchTime }
                let name = stats.first?.channelName ?? "Unknown"
                return ChannelStat(channelId: channelId, channelName: name, watchTime: totalTime)
            }.sorted { $0.watchTime > $1.watchTime }

            let totalTime = channelStats.reduce(0) { $0 + $1.watchTime }

            return GroupedStats(date: date, channels: channelStats, totalWatchTime: totalTime)
        }
    }

    @MainActor
    func channelWatchTime(channelId: String, scope: ChannelChartScope) -> [WatchTimePoint] {
        let entries = rawStats
            .filter { $0.channelId == channelId }
            .sorted { $0.date < $1.date }
        guard let component = scope.component else {
            return cumulative(entries)
        }
        var calendar = Calendar.current
        calendar.timeZone = .gmt
        let grouped = Dictionary(grouping: entries) {
            calendar.dateInterval(of: component, for: $0.date)?.start ?? $0.date
        }
        guard let first = grouped.keys.min(), let last = grouped.keys.max() else { return [] }
        var points: [WatchTimePoint] = []
        var period = first
        while period <= last {
            let time = grouped[period]?.reduce(0) { $0 + $1.watchTime } ?? 0
            points.append(WatchTimePoint(date: period, time: time))
            guard let next = calendar.date(byAdding: component, value: 1, to: period) else { break }
            period = next
        }
        return points
    }

    @MainActor
    private func cumulative(_ entries: [SendableWatchTimeEntry]) -> [WatchTimePoint] {
        var total: TimeInterval = 0
        var points = entries.map { entry in
            total += entry.watchTime
            return WatchTimePoint(date: entry.date, time: total)
        }
        if let last = points.last, let today = StatsService.shared.getNormalizedDate(Date()), last.date < today {
            points.append(WatchTimePoint(date: today, time: last.time))
        }
        return points
    }
}

struct WatchTimePoint: Identifiable {
    var id: Date { date }
    let date: Date
    let time: TimeInterval
}

extension [WatchTimePoint] {
    var linearTrend: (start: WatchTimePoint, end: WatchTimePoint)? {
        guard count >= 2, let first, let last else { return nil }
        let pointCount = Double(count)
        let positions = indices.map(Double.init)
        let meanX = positions.reduce(0, +) / pointCount
        let meanY = reduce(0) { $0 + $1.time } / pointCount
        let covariance = zip(positions, self).reduce(0) { $0 + ($1.0 - meanX) * ($1.1.time - meanY) }
        let variance = positions.reduce(0) { $0 + ($1 - meanX) * ($1 - meanX) }
        let slope = covariance / variance
        let intercept = meanY - slope * meanX
        return (
            WatchTimePoint(date: first.date, time: Swift.max(0, intercept)),
            WatchTimePoint(date: last.date, time: Swift.max(0, intercept + slope * (pointCount - 1)))
        )
    }
}

enum ChannelChartScope: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case total = "Total"
    var id: Self { self }

    var component: Calendar.Component? {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        case .total: nil
        }
    }
}

enum StatsScope: String, CaseIterable, Identifiable {
    case day = "Day"
    case month = "Month"
    case year = "Year"
    case total = "Total"
    var id: Self { self }
}

struct StatsChannelImage: Sendable {
    let thumbnailUrl: URL?
    let isPodcast: Bool
}

extension [String: StatsChannelImage] {
    /// Podcasts without a subscription are still keyed by their feed URL.
    func isPodcast(_ channelId: String) -> Bool {
        self[channelId]?.isPodcast ?? channelId.contains("://")
    }
}

struct ChannelStat: Identifiable, Sendable {
    var id: String { channelId }
    let channelId: String
    let channelName: String
    let watchTime: TimeInterval
}

struct GroupedStats: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let channels: [ChannelStat]
    let totalWatchTime: TimeInterval
}
