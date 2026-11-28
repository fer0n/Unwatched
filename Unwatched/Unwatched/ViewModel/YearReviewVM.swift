//
//  YearReviewVM.swift
//  Unwatched
//

import Foundation
import UnwatchedShared
import OSLog

enum YearReviewCard: Hashable {
    case intro, totalTime, videos, topChannels, tags, mediaSplit, busiestMonth, topDays, daysWatched, streak, outro
}

@Observable @MainActor
final class YearReviewVM {
    var review: YearReview?
    var availableYears: [Int] = []
    var isLoading = true
    var year = YearReviewVM.defaultYear {
        didSet { updateReview() }
    }

    private var source = YearReviewSource()

    var images: [String: StatsChannelImage] { source.images }

    nonisolated static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Last year during January, so the review isn't a few days long.
    private static var defaultYear: Int {
        let now = Calendar.current.dateComponents([.year, .month], from: .now)
        let year = now.year ?? 2026
        return now.month == 1 ? year - 1 : year
    }

    private static var today: Date {
        StatsService.shared.getNormalizedDate(.now) ?? .now
    }

    func load() async {
        await StatsService.shared.flush()?.value
        let task = Task.detached {
            let actor = StatsActor()
            return (
                try await actor.getStats(),
                try await actor.getChannelImages(),
                try await actor.getWatchedItems(),
                try await actor.getTagChannels()
            )
        }
        do {
            let (entries, images, watchedItems, tags) = try await task.value
            source = YearReviewSource(entries: entries, images: images, watchedItems: watchedItems, tags: tags)
        } catch {
            Log.error("YearReviewVM: failed to load: \(error)")
        }
        let calendar = Self.calendar
        availableYears = Set(source.entries.map { calendar.component(.year, from: $0.date) }).sorted(by: >)
        if !availableYears.contains(year), let latest = availableYears.first {
            year = latest
        } else {
            updateReview()
        }
        isLoading = false
    }

    private func updateReview() {
        review = YearReview.make(
            year: year,
            source: source,
            today: Self.today
        )
    }
}
