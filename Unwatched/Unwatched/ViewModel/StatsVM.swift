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

        let task = Task.detached {
            let actor = StatsActor(modelContainer: DataProvider.shared.container)
            return try await actor.getStats()
        }

        do {
            rawStats = try await task.value
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
        }

        let task = Task.detached {
            let actor = StatsActor(modelContainer: DataProvider.shared.container)
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
}

enum StatsScope: String, CaseIterable, Identifiable {
    case day = "Day"
    case month = "Month"
    case year = "Year"
    var id: Self { self }
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
