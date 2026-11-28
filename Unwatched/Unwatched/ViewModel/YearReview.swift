//
//  YearReview.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

struct WatchedItem: Sendable {
    let date: Date
    let isPodcast: Bool
}

struct TagChannels: Sendable {
    let id: String
    let name: String
    let symbol: String
    let channelIds: Set<String>
    let isExcluding: Bool
    let podcasts: TagPodcasts

    func contains(_ channelId: String, isPodcast: Bool) -> Bool {
        switch podcasts {
        case .all where isPodcast: true
        case .hidden where isPodcast: false
        default: channelIds.contains(channelId) != isExcluding
        }
    }
}

enum YearReviewMedia: CaseIterable {
    case all, videos, podcasts
}

struct YearReviewSource {
    var entries: [SendableWatchTimeEntry] = []
    var images: [String: StatsChannelImage] = [:]
    var watchedItems: [WatchedItem] = []
    var tags: [TagChannels] = []
}

struct RaceEntry: Identifiable {
    let id: String
    let name: String
    let symbol: String?
    let cumulative: [TimeInterval]

    var total: TimeInterval { cumulative.last ?? 0 }
}

struct YearReview {
    let year: Int
    let totalTime: TimeInterval
    let podcastTime: TimeInterval
    let videoTime: TimeInterval
    let videosWatched: Int
    let episodesWatched: Int
    let topChannels: [ChannelStat]
    let channelCount: Int
    let topPodcasts: [ChannelStat]
    let topVideoChannels: [ChannelStat]
    let channelRace: [YearReviewMedia: [RaceEntry]]
    let tagRace: [RaceEntry]
    /// Month index of the last day of each race step (a week).
    let raceStepMonths: [Int]
    let months: [WatchTimePoint]
    let topDays: [WatchTimePoint]
    let activeDays: Int
    let daysInYear: Int
    let isCurrentYear: Bool
    let streakDays: [Date]
    let watchedDays: Set<Date>
    /// Each watched day's position in date order.
    let watchedDayOrder: [Date: Int]
    /// Jan 1 through Dec 31, or through today for the current year.
    let reviewedDays: ClosedRange<Date>

    var longestStreak: Int { streakDays.count }

    var hasBothMedia: Bool { podcastTime >= 60 && videoTime >= 60 }

    var cards: [YearReviewCard] {
        guard totalTime > 0 else { return [.intro] }
        var cards: [YearReviewCard] = [.intro, .totalTime]
        if videosWatched + episodesWatched > 0 { cards.append(.videos) }
        if channelRace[.all]?.isEmpty == false { cards.append(.topChannels) }
        if !tagRace.isEmpty { cards.append(.tags) }
        if hasBothMedia { cards.append(.mediaSplit) }
        cards += [.busiestMonth, .topDays]
        if longestStreak > 1 { cards.append(.streak) }
        return cards + [.daysWatched, .outro]
    }
    var activeDaysShare: Double { Double(activeDays) / Double(max(daysInYear, 1)) }

    var busiestMonthIndex: Int {
        months.indices.max { months[$0].time < months[$1].time } ?? 0
    }

    static func make(
        year: Int,
        source: YearReviewSource,
        today: Date
    ) -> YearReview {
        let calendar = YearReviewVM.calendar
        let yearEntries = source.entries.filter { calendar.component(.year, from: $0.date) == year }
        let isCurrentYear = calendar.component(.year, from: today) == year
        let dayCount = daysInYear(year, today: isCurrentYear ? today : nil, calendar: calendar)
        let weekCount = (dayCount + 6) / 7
        let yearStart = calendar.date(from: DateComponents(year: year)) ?? today
        let lastDay = calendar.date(byAdding: .day, value: dayCount - 1, to: yearStart) ?? yearStart

        let topChannels = channelStats(yearEntries)
        let weekly = weeklyTime(yearEntries, weekCount: weekCount, calendar: calendar)

        let byDay = Dictionary(grouping: yearEntries, by: \.date)
            .mapValues { $0.reduce(0) { $0 + $1.watchTime } }
        let days = byDay.keys.sorted()

        let watched = source.watchedItems.filter { Calendar.current.component(.year, from: $0.date) == year }
        let podcasts = topChannels.filter { source.images.isPodcast($0.channelId) }
        let videoChannels = topChannels.filter { !source.images.isPodcast($0.channelId) }

        return YearReview(
            year: year,
            totalTime: yearEntries.reduce(0) { $0 + $1.watchTime },
            podcastTime: podcasts.reduce(0) { $0 + $1.watchTime },
            videoTime: videoChannels.reduce(0) { $0 + $1.watchTime },
            videosWatched: watched.filter { !$0.isPodcast }.count,
            episodesWatched: watched.filter(\.isPodcast).count,
            topChannels: Array(topChannels.prefix(5)),
            channelCount: topChannels.count,
            topPodcasts: Array(podcasts.prefix(3)),
            topVideoChannels: Array(videoChannels.prefix(3)),
            channelRace: [
                .all: channelRace(topChannels, weekly: weekly),
                .videos: channelRace(videoChannels, weekly: weekly),
                .podcasts: channelRace(podcasts, weekly: weekly)
            ],
            tagRace: tagRace(source.tags, weekly: weekly, weekCount: weekCount, images: source.images),
            raceStepMonths: raceStepMonths(year: year, weekCount: weekCount, dayCount: dayCount, calendar: calendar),
            months: months(year: year, entries: yearEntries, calendar: calendar),
            topDays: byDay.sorted { $0.value > $1.value }
                .prefix(3)
                .map { WatchTimePoint(date: $0.key, time: $0.value) },
            activeDays: days.count,
            daysInYear: dayCount,
            isCurrentYear: isCurrentYear,
            streakDays: longestStreak(days, calendar: calendar),
            watchedDays: Set(days),
            watchedDayOrder: Dictionary(uniqueKeysWithValues: days.enumerated().map { ($1, $0) }),
            reviewedDays: yearStart...max(lastDay, yearStart)
        )
    }

    private static func channelStats(_ entries: [SendableWatchTimeEntry]) -> [ChannelStat] {
        Dictionary(grouping: entries, by: \.channelId)
            .map { channelId, entries in
                ChannelStat(
                    channelId: channelId,
                    channelName: entries.first?.channelName ?? channelId,
                    watchTime: entries.reduce(0) { $0 + $1.watchTime }
                )
            }
            .sorted { $0.watchTime > $1.watchTime }
    }

    private static func months(year: Int, entries: [SendableWatchTimeEntry], calendar: Calendar) -> [WatchTimePoint] {
        (1...12).compactMap { month in
            guard let start = calendar.date(from: DateComponents(year: year, month: month)) else { return nil }
            let time = entries
                .filter { calendar.component(.month, from: $0.date) == month }
                .reduce(0) { $0 + $1.watchTime }
            return WatchTimePoint(date: start, time: time)
        }
    }

    private static func weeklyTime(
        _ entries: [SendableWatchTimeEntry],
        weekCount: Int,
        calendar: Calendar
    ) -> [String: [TimeInterval]] {
        var weekly: [String: [TimeInterval]] = [:]
        for entry in entries {
            let week = ((calendar.ordinality(of: .day, in: .year, for: entry.date) ?? 1) - 1) / 7
            guard week < weekCount else { continue }
            weekly[entry.channelId, default: Array(repeating: 0, count: weekCount)][week] += entry.watchTime
        }
        return weekly.mapValues(cumulative)
    }

    private static func raceStepMonths(year: Int, weekCount: Int, dayCount: Int, calendar: Calendar) -> [Int] {
        guard let start = calendar.date(from: DateComponents(year: year)) else { return [] }
        return (0..<weekCount).map { week in
            let lastDay = min(week * 7 + 6, dayCount - 1)
            let date = calendar.date(byAdding: .day, value: lastDay, to: start) ?? start
            return calendar.component(.month, from: date) - 1
        }
    }

    private static func cumulative(_ values: [TimeInterval]) -> [TimeInterval] {
        var total: TimeInterval = 0
        return values.map { total += $0; return total }
    }

    private static func channelRace(_ channels: [ChannelStat], weekly: [String: [TimeInterval]]) -> [RaceEntry] {
        channels.prefix(5).map {
            RaceEntry(id: $0.channelId, name: $0.channelName, symbol: nil, cumulative: weekly[$0.channelId] ?? [])
        }
    }

    private static func tagRace(
        _ tags: [TagChannels],
        weekly: [String: [TimeInterval]],
        weekCount: Int,
        images: [String: StatsChannelImage]
    ) -> [RaceEntry] {
        let entries = tags.map { tag in
            let series = weekly.filter { tag.contains($0.key, isPodcast: images.isPodcast($0.key)) }.values
            let sum = (0..<weekCount).map { week in series.reduce(0) { $0 + $1[week] } }
            return RaceEntry(id: tag.id, name: tag.name, symbol: tag.symbol, cumulative: sum)
        }
        return Array(entries.filter { $0.total > 0 }.sorted { $0.total > $1.total }.prefix(5))
    }

    private static func daysInYear(_ year: Int, today: Date?, calendar: Calendar) -> Int {
        if let today {
            return calendar.ordinality(of: .day, in: .year, for: today) ?? 365
        }
        guard let start = calendar.date(from: DateComponents(year: year)) else { return 365 }
        return calendar.range(of: .day, in: .year, for: start)?.count ?? 365
    }

    private static func longestStreak(_ days: [Date], calendar: Calendar) -> [Date] {
        var longest: [Date] = []
        var current: [Date] = []
        for day in days {
            if let previous = current.last, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                current.append(day)
            } else {
                current = [day]
            }
            if current.count > longest.count {
                longest = current
            }
        }
        return longest
    }
}
