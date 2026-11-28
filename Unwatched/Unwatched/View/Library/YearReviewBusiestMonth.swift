//
//  YearReviewBusiestMonth.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct YearReviewBusiestMonth: View {
    let months: [WatchTimePoint]
    let busiest: Int
    let isActive: Bool
    var skipped = false

    @State private var grown = false
    @State private var highlighted: Int?
    @State private var landed = false
    @State private var widestName: CGFloat = 0
    @State private var availableWidth: CGFloat = 0

    private static let nameSize: CGFloat = 64

    var body: some View {
        let shown = highlighted ?? busiest
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                ReviewCaption(text: Text("yearReviewBusiestMonth"))
                Text(YearReviewFormat.monthName(shown))
                    .font(.system(size: Self.nameSize * sharedNameScale, weight: .black))
                    .lineLimit(1)
                    .fixedSize()
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background { widestMonthName }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
                    .transaction { $0.animation = nil }
                    .scaleEffect(landed ? 1 : 0.85)
                    .opacity(highlighted == nil ? 0 : 1)
                Text(YearReviewFormat.hours(months[shown].time))
                    .font(.title3)
                    .monospacedDigit()
                    .frame(height: 28)
                    .transaction { $0.animation = nil }
                    .opacity(landed ? 0.8 : 0)
            }
            monthBars
        }
        .sensoryFeedback(.selection, trigger: highlighted) { $1 != nil && !skipped }
        .sensoryFeedback(.impact(weight: .heavy), trigger: landed) { $1 && !skipped }
        .reviewAnimation(isActive: isActive, skipped: skipped) {
            grown = false
            highlighted = nil
            landed = false
        } finish: {
            grown = true
            highlighted = busiest
            landed = true
        } animate: {
            await run()
        }
    }

    private var sharedNameScale: CGFloat {
        widestName > 0 && availableWidth > 0 ? min(1, availableWidth / widestName) : 1
    }

    private var widestMonthName: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { month in
                Text(YearReviewFormat.monthName(month))
                    .font(.system(size: Self.nameSize, weight: .black))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .hidden()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { widestName = $0 }
    }

    private var monthBars: some View {
        let longest = max(months.map(\.time).max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(months.indices, id: \.self) { monthIndex in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(monthIndex == highlighted ? 1 : 0.35))
                        .frame(height: barHeight(monthIndex, longest: longest))
                    Text(YearReviewFormat.shortMonthName(monthIndex))
                        .font(.caption2)
                        .opacity(0.7)
                }
            }
        }
        .frame(height: 140, alignment: .bottom)
    }

    /// Bars stay level while the highlight cycles, so the winner only shows once it lands.
    private func barHeight(_ monthIndex: Int, longest: TimeInterval) -> CGFloat {
        if landed { return max(2, 120 * months[monthIndex].time / longest) }
        return grown ? 60 : 2
    }

    static func duration(busiest: Int) -> Double {
        let path = slotPath(busiest)
        return 0.8 + path.indices.reduce(0) { $0 + slotDelay(remaining: path.count - $1) } + 0.7
    }

    private static func slotPath(_ busiest: Int) -> [Int] {
        Array(0..<12) + Array(0...busiest)
    }

    private static func slotDelay(remaining: Int) -> Double {
        remaining < 5 ? 0.2 + 0.1 * Double(5 - remaining) : 0.11
    }

    private func run() async {
        withAnimation(.easeOut(duration: 1.0)) { grown = true }
        try? await Task.sleep(for: .seconds(0.8))
        let path = Self.slotPath(busiest)
        for (step, month) in path.enumerated() {
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.12)) { highlighted = month }
            try? await Task.sleep(for: .seconds(Self.slotDelay(remaining: path.count - step)))
        }
        guard !Task.isCancelled else { return }
        withAnimation(.spring(duration: 0.7, bounce: 0.4)) { landed = true }
    }
}
