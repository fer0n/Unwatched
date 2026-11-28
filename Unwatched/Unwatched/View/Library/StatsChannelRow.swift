//
//  StatsChannelRow.swift
//  Unwatched
//

import SwiftUI
import Charts
import UnwatchedShared

struct StatsChannelRow: View {
    @Environment(\.displayScale) private var displayScale

    let channel: ChannelStat
    let image: StatsChannelImage?
    let viewModel: StatsVM
    let selectedDate: Date

    @State private var showDeleteAlert = false

    #if os(macOS)
    @ScaledMetric private var imageSize = 22
    #else
    @ScaledMetric private var imageSize = 30
    #endif

    var body: some View {
        NavigationLink {
            StatsChannelChart(channel: channel, viewModel: viewModel)
        } label: {
            HStack(spacing: 10) {
                channelImage
                    .accessibilityHidden(true)
                Text(channel.channelName)
                    .lineLimit(1)
                Spacer()
                Text(Duration.seconds(channel.watchTime).formatted(.time(pattern: .hourMinuteSecond)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                showDeleteAlert = true
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
        .confirmationDialog("reallyDelete", isPresented: $showDeleteAlert, titleVisibility: .visible) {
            Button("delete", role: .destructive) {
                Task {
                    await viewModel.deleteStats(date: selectedDate, channelId: channel.channelId)
                }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("deleteStatsConfirmation \(channel.channelName)")
        }
    }

    private var channelImage: some View {
        CachedImageView(imageUrl: image?.thumbnailUrl, maxPixelSize: ceil(imageSize * displayScale)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(.secondary)
        }
        .frame(width: imageSize, height: imageSize)
        .channelImageClip(isPodcast: image?.isPodcast ?? false)
    }
}

struct StatsChannelChart: View {
    let channel: ChannelStat
    let viewModel: StatsVM

    @State private var scope: ChannelChartScope = .month
    @State private var selection: Date?

    var body: some View {
        let points = viewModel.channelWatchTime(channelId: channel.channelId, scope: scope)
        let total = viewModel.channelWatchTime(channelId: channel.channelId, scope: .total).last?.time ?? 0
        ZStack {
            MyBackgroundColor()

            List {
                MySection {
                    HStack {
                        Label("totalWatchTime", systemImage: "clock")
                        Spacer()
                        Text(Duration.seconds(total).formatted(.time(pattern: .hourMinuteSecond)))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                MySection {
                    VStack(alignment: .leading, spacing: 15) {
                        summary(points)

                        chart(points)
                            .frame(height: 250)
                            .id(scope)
                    }
                    .padding(.vertical)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .safeAreaBar(edge: .top) {
            Picker("scope", selection: $scope) {
                ForEach(ChannelChartScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .onChange(of: scope) {
            selection = nil
        }
        .myNavigationTitle(LocalizedStringKey(channel.channelName))
    }

    private func summary(_ points: [WatchTimePoint]) -> some View {
        let selected = selectedPoint(in: points)
        let title: String
        let time: TimeInterval
        if let selected {
            title = periodLabel(selected.date)
            time = selected.time
        } else if scope == .total {
            title = String(localized: "totalWatchTime")
            time = points.last?.time ?? 0
        } else {
            title = String(localized: "average")
            time = average(points)
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatted(time))
                .font(.title2.bold())
                .monospacedDigit()
        }
    }

    private func chart(_ points: [WatchTimePoint]) -> some View {
        let selected = selectedPoint(in: points)
        let visibleLength = visibleDomainLength(points)
        return Chart {
            if let component = scope.component {
                barMarks(points, component: component, selected: selected)
            } else {
                cumulativeMarks(points, selected: selected)
            }
        }
        .chartXSelection(value: $selection)
        .chartGesture { proxy in
            SpatialTapGesture().onEnded { value in
                guard let date: Date = proxy.value(atX: value.location.x) else { return }
                let tapped = point(at: date, in: points)
                selection = tapped == nil || tapped?.date == selected?.date ? nil : date
            }
        }
        .chartScrollableAxes(visibleLength == nil ? [] : .horizontal)
        .chartXVisibleDomain(length: visibleLength ?? domainLength(points))
        .chartScrollPosition(initialX: initialScrollX(points, visibleLength: visibleLength))
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text(formatted(hours * 3600))
                    }
                }
            }
        }
    }

    @ChartContentBuilder
    private func barMarks(
        _ points: [WatchTimePoint],
        component: Calendar.Component,
        selected: WatchTimePoint?
    ) -> some ChartContent {
        ForEach(points) { point in
            BarMark(
                x: .value("date", point.date, unit: component, calendar: chartCalendar),
                y: .value("hours", point.time / 3600)
            )
            .foregroundStyle(Color.accentColor.opacity(selected == nil || selected?.date == point.date ? 1 : 0.4))
        }
        if selected == nil, !points.isEmpty {
            RuleMark(y: .value("average", average(points) / 3600))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.secondary)
        }
        if let trend = points.linearTrend {
            ForEach([trend.start, trend.end]) { point in
                LineMark(
                    x: .value("date", point.date, unit: component, calendar: chartCalendar),
                    y: .value("trend", point.time / 3600)
                )
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .foregroundStyle(.primary.opacity(0.5))
            }
        }
    }

    @ChartContentBuilder
    private func cumulativeMarks(_ points: [WatchTimePoint], selected: WatchTimePoint?) -> some ChartContent {
        ForEach(points) { point in
            AreaMark(
                x: .value("date", point.date),
                y: .value("hours", point.time / 3600)
            )
            .interpolationMethod(.stepEnd)
            .foregroundStyle(Color.accentColor.opacity(0.2))

            LineMark(
                x: .value("date", point.date),
                y: .value("hours", point.time / 3600)
            )
            .interpolationMethod(.stepEnd)
            .foregroundStyle(Color.accentColor)
        }
        if let selected {
            RuleMark(x: .value("date", selected.date))
                .foregroundStyle(.secondary)
        }
    }

    private var chartCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = .gmt
        return calendar
    }

    private var periodSeconds: TimeInterval {
        switch scope {
        case .week: 7 * 86400
        case .month: 31 * 86400
        case .year, .total: 366 * 86400
        }
    }

    private var maxVisiblePeriods: Double? {
        switch scope {
        case .week: 26
        case .month: 12
        case .year, .total: nil
        }
    }

    private func domainLength(_ points: [WatchTimePoint]) -> TimeInterval {
        guard let first = points.first?.date, let last = points.last?.date else { return periodSeconds }
        let span = last.timeIntervalSince(first)
        return scope == .total ? max(span, 86400) : span + periodSeconds
    }

    private func visibleDomainLength(_ points: [WatchTimePoint]) -> TimeInterval? {
        guard let maxVisiblePeriods else { return nil }
        let maxLength = maxVisiblePeriods * periodSeconds
        return domainLength(points) > maxLength ? maxLength : nil
    }

    private func initialScrollX(_ points: [WatchTimePoint], visibleLength: TimeInterval?) -> Date {
        guard let last = points.last?.date else { return .now }
        guard let visibleLength else { return points.first?.date ?? last }
        return last.addingTimeInterval(periodSeconds - visibleLength)
    }

    private func selectedPoint(in points: [WatchTimePoint]) -> WatchTimePoint? {
        selection.flatMap { point(at: $0, in: points) }
    }

    private func point(at date: Date, in points: [WatchTimePoint]) -> WatchTimePoint? {
        if let component = scope.component {
            let start = chartCalendar.dateInterval(of: component, for: date)?.start
            return points.first { $0.date == start }
        }
        return points.last { $0.date <= date } ?? points.first
    }

    private func average(_ points: [WatchTimePoint]) -> TimeInterval {
        guard !points.isEmpty else { return 0 }
        return points.reduce(0) { $0 + $1.time } / Double(points.count)
    }

    private func periodLabel(_ date: Date) -> String {
        var style: Date.FormatStyle
        switch scope {
        case .week, .total: style = .dateTime.day().month(.abbreviated).year()
        case .month: style = .dateTime.month(.wide).year()
        case .year: style = .dateTime.year()
        }
        style.timeZone = .gmt
        return date.formatted(style)
    }

    private func formatted(_ time: TimeInterval) -> String {
        Duration.seconds(time).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}
