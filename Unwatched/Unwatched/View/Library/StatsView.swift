//
//  StatsView.swift
//  Unwatched
//

import SwiftUI
import Charts
import SwiftData
import UnwatchedShared

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = StatsVM()
    @State private var selectedDate = Date()
    @State private var resetTrigger = false

    var body: some View {
        ZStack {
            MyBackgroundColor()

            List {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if let stats = currentStats {
                        MySection {
                            HStack {
                                Text("totalWatchTime")
                                Spacer()
                                Text(formatDuration(stats.totalWatchTime))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }

                        MySection("channels") {
                            ForEach(stats.channels) { channel in
                                StatsChannelRow(channel: channel, viewModel: viewModel, selectedDate: selectedDate)
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "noData",
                            systemImage: "chart.bar.fill",
                            description: Text(
                                "noWatchHistory"
                            )
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .showStatsToolbarItem(false)
        }
        .task {
            await viewModel.loadStats()
        }
        .myNavigationTitle("stats")
        .apply {
            if #available(iOS 26.0, visionOS 26.0, macOS 26.0, *) {
                $0.safeAreaBar(edge: .top) {
                    controls
                }
            } else {
                $0.safeAreaInset(edge: .top) {
                    controls
                        .padding(.top, 5)
                        .background(MyBackgroundColor())
                }
            }
        }
    }

    @ViewBuilder
    var controls: some View {
        VStack(spacing: 5) {
            HStack {
                Picker("scope", selection: $viewModel.scope) {
                    ForEach(StatsScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal)

            HStack {
                Button(action: previousDate) {
                    Image(systemName: "arrow.left")
                        .padding(Device.isMac ? 0 : 10)
                }
                .disabled(isPreviousDisabled)

                Spacer()

                Text(formatDate(selectedDate, scope: viewModel.scope))
                    .font(.headline)
                    .sensoryFeedback(Const.sensoryFeedback, trigger: resetTrigger)
                    .onTapGesture {
                        selectedDate = Date()
                        resetTrigger.toggle()
                    }

                Spacer()

                Button(action: nextDate) {
                    Image(systemName: "arrow.right")
                        .padding(Device.isMac ? 0 : 10)
                }
                .disabled(isNextDisabled)
            }
            #if os(visionOS)
            .tint(nil)
            .foregroundStyle(.primary)
            #endif
            .padding(.horizontal)
            .padding(.vertical, 5)
        }
    }

    private var statsCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private var normalizedSelectedDate: Date {
        guard let normalizedDay = StatsService.shared.getNormalizedDate(selectedDate) else { return selectedDate }

        if viewModel.scope == .day {
            return normalizedDay
        }

        switch viewModel.scope {
        case .month:
            let components = statsCalendar.dateComponents([.year, .month], from: normalizedDay)
            return statsCalendar.date(from: components) ?? normalizedDay
        case .year:
            let components = statsCalendar.dateComponents([.year], from: normalizedDay)
            return statsCalendar.date(from: components) ?? normalizedDay
        default:
            return normalizedDay
        }
    }

    private var currentStats: GroupedStats? {
        let normalized = normalizedSelectedDate
        return viewModel.groupedStats.first {
            // Compare using GMT calendar since groupedStats dates are normalized to GMT
            return statsCalendar.isDate(
                $0.date,
                equalTo: normalized,
                toGranularity: .second
            )
        }
    }

    private var isPreviousDisabled: Bool {
        let normalized = normalizedSelectedDate
        return !viewModel.groupedStats.contains { $0.date < normalized }
    }

    private var isNextDisabled: Bool {
        let normalized = normalizedSelectedDate
        if viewModel.groupedStats.contains(where: { $0.date > normalized }) {
            return false
        }

        guard let gmtNow = StatsService.shared.getNormalizedDate(Date()) else { return true }

        let granularity: Calendar.Component
        switch viewModel.scope {
        case .day: granularity = .day
        case .month: granularity = .month
        case .year: granularity = .year
        }

        return statsCalendar.compare(normalized, to: gmtNow, toGranularity: granularity) != .orderedAscending
    }

    private func previousDate() {
        let normalized = normalizedSelectedDate
        if let prevStat = viewModel.groupedStats.first(where: { $0.date < normalized }) {
            selectedDate = toLocalNoon(fromNormalized: prevStat.date)
        }
    }

    private func nextDate() {
        let normalized = normalizedSelectedDate
        if let nextStat = viewModel.groupedStats.reversed().first(where: { $0.date > normalized }) {
            selectedDate = toLocalNoon(fromNormalized: nextStat.date)
        } else {
            selectedDate = Date()
        }
    }

    private func toLocalNoon(fromNormalized gmtDate: Date) -> Date {
        let components = statsCalendar.dateComponents([.year, .month, .day], from: gmtDate)
        var localComponents = DateComponents()
        localComponents.year = components.year
        localComponents.month = components.month
        localComponents.day = components.day
        localComponents.hour = 12
        return Calendar.current.date(from: localComponents) ?? gmtDate
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond))
    }

    private func formatDate(_ date: Date, scope: StatsScope) -> String {
        let normalized = StatsService.shared.getNormalizedDate(date) ?? date

        switch scope {
        case .day:
            if let gmtToday = StatsService.shared.getNormalizedDate(Date()) {
                if statsCalendar.isDate(normalized, inSameDayAs: gmtToday) {
                    return "Today"
                } else if let gmtYesterday = statsCalendar.date(byAdding: .day, value: -1, to: gmtToday),
                          statsCalendar.isDate(normalized, inSameDayAs: gmtYesterday) {
                    return "Yesterday"
                }
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            formatter.timeZone = statsCalendar.timeZone
            return formatter.string(from: normalized)

        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            formatter.timeZone = statsCalendar.timeZone
            return formatter.string(from: normalized)

        case .year:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy"
            formatter.timeZone = statsCalendar.timeZone
            return formatter.string(from: normalized)
        }
    }
}

#Preview {
    StatsView()
        .previewEnvironments()
}
