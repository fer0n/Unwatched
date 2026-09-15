//
//  CarriedTime.swift
//  UnwatchedWatch
//

import SwiftUI
import UnwatchedShared

/// Redraws its content as the phone's timeline moves, and only its content: ticking the player page
/// itself re-evaluates all of it.
struct CarriedTime<Content: View>: View {
    let timeline: WatchTimeline
    /// How long until what `content` draws would look different.
    let step: (Date) -> TimeInterval
    @ViewBuilder let content: (Date) -> Content

    /// Always On redraws about once a minute, so carrying the position there is all cost.
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        if timeline.isMoving && !isLuminanceReduced {
            TimelineView(CarriedSchedule(step: step)) { context in
                content(context.date)
            }
        } else {
            content(.now)
        }
    }
}

private struct CarriedSchedule: TimelineSchedule {
    let step: (Date) -> TimeInterval

    func entries(from startDate: Date, mode: Mode) -> AnyIterator<Date> {
        var next = startDate
        return AnyIterator {
            defer { next = next.addingTimeInterval(max(Self.minimum, step(next))) }
            return next
        }
    }

    private static let minimum: TimeInterval = 0.5
}
