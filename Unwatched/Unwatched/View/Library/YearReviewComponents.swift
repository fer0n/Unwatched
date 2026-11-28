//
//  YearReviewComponents.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

enum YearReviewFormat {
    static func hours(_ time: TimeInterval) -> String {
        Duration.seconds(time).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    static func timestamp(_ time: TimeInterval, hourDigits: Int) -> String {
        Duration.seconds(max(time, 0))
            .formatted(.time(pattern: .hourMinute(padHourToLength: hourDigits, roundSeconds: .down)))
    }

    static func days(_ days: Int) -> String {
        Duration.seconds(Double(days) * 86400).formatted(.units(allowed: [.days], width: .wide))
    }

    static func digits(_ value: Double) -> Int {
        String(Int(max(value, 0))).count
    }

    /// Whole `unit`s padded to `digits`, so a count-up keeps the same width throughout.
    static func padded(
        _ seconds: TimeInterval,
        unit: Duration.UnitsFormatStyle.Unit,
        digits: Int,
        width: Duration.UnitsFormatStyle.UnitWidth = .wide
    ) -> String {
        Duration.seconds(max(seconds, 0)).formatted(unitsStyle(unit, digits: digits, width: width))
    }

    private static func unitsStyle(
        _ unit: Duration.UnitsFormatStyle.Unit,
        digits: Int,
        width: Duration.UnitsFormatStyle.UnitWidth
    ) -> Duration.UnitsFormatStyle {
        Duration.UnitsFormatStyle(
            allowedUnits: [unit], width: width, zeroValueUnits: .show(length: digits), valueLength: digits,
            fractionalPart: .hide(rounded: .down)
        )
    }

    /// Like `padded`, with the unit shortened, smaller and dimmed next to the number.
    static func paddedNumber(
        _ seconds: TimeInterval,
        unit: Duration.UnitsFormatStyle.Unit,
        digits: Int,
        unitFont: Font
    ) -> AttributedString {
        let style = unitsStyle(unit, digits: digits, width: .abbreviated)
        var text = Duration.seconds(max(seconds, 0)).formatted(style.attributed)
        for run in text.runs where run.measurement == .unit {
            text[run.range].font = unitFont
            text[run.range].foregroundColor = .white.opacity(0.6)
        }
        return text
    }

    /// A count-up format for `target` seconds whose text keeps the same digit count while counting.
    static func countingHours(target: TimeInterval) -> (Double) -> String {
        let targetHours = (target / 3600).rounded(.down)
        guard targetHours > 0 else {
            let digits = digits(target / 60)
            return { padded($0, unit: .minutes, digits: digits, width: .abbreviated) }
        }
        let digits = digits(targetHours)
        return { value in
            let hours = (value / 3600).rounded(.down) * 3600
            let hoursText = padded(hours, unit: .hours, digits: digits, width: .abbreviated)
            let minutesText = padded(value - hours, unit: .minutes, digits: 2, width: .abbreviated)
            return "\(hoursText) \(minutesText)"
        }
    }

    static func gmt(_ style: Date.FormatStyle) -> Date.FormatStyle {
        var style = style
        style.timeZone = .gmt
        return style
    }

    private static let monthCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        return calendar
    }()

    static func monthName(_ index: Int) -> String {
        monthCalendar.standaloneMonthSymbols[index]
    }

    static func shortMonthName(_ index: Int) -> String {
        monthCalendar.veryShortStandaloneMonthSymbols[index]
    }
}

struct CountUpText: View, Animatable {
    var value: Double
    let target: Double
    let format: (Double) -> AttributedString
    let widest: AttributedString?

    init(
        target: Double,
        isOn: Bool,
        widest: AttributedString? = nil,
        attributed format: @escaping (Double) -> AttributedString
    ) {
        self.value = isOn ? target : 0
        self.target = target
        self.widest = widest
        self.format = format
    }

    init(target: Double, isOn: Bool, format: @escaping (Double) -> String) {
        self.init(target: target, isOn: isOn) { AttributedString(format($0)) }
    }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(widest ?? format(target))
            .hidden()
            .overlay {
                Text(format(value))
            }
            .monospacedDigit()
    }
}

private struct ReviewPhase: Hashable {
    let isActive: Bool
    let skipped: Bool
}

extension View {
    /// Animates while the slide is active, jumps to the end state once skipped, resets after it fades out.
    func reviewAnimation(
        isActive: Bool,
        skipped: Bool,
        reset: @escaping () -> Void,
        finish: @escaping () -> Void,
        animate: @escaping () async -> Void
    ) -> some View {
        task(id: ReviewPhase(isActive: isActive, skipped: skipped)) {
            guard isActive else {
                await YearReviewReset.afterFade()
                reset()
                return
            }
            guard !skipped else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction, finish)
                return
            }
            await animate()
        }
    }
}

enum CountUpTiming {
    static let delay = 0.3
    static let duration = 2.2
    static let totalTimeDuration = 2.6

    static func total(duration: Double = duration) -> Double {
        delay + duration
    }
}

enum YearReviewReset {
    static let fadeDuration = 0.3

    static func afterFade() async {
        try? await Task.sleep(for: .seconds(fadeDuration))
    }
}

struct LandingHaptic: ViewModifier {
    let isActive: Bool
    let delay: Double

    @State private var landed = false

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.impact(weight: .heavy), trigger: landed) { $1 }
            .task(id: isActive) {
                landed = false
                guard isActive else { return }
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                landed = true
            }
    }
}

extension View {
    func landingHaptic(_ isActive: Bool, after delay: Double) -> some View {
        modifier(LandingHaptic(isActive: isActive, delay: delay))
    }

    func countUp(
        _ isActive: Bool,
        duration: Double = CountUpTiming.duration,
        delay: Double = CountUpTiming.delay
    ) -> some View {
        animation(
            isActive
                ? .easeOut(duration: duration).delay(delay)
                : .linear(duration: 0).delay(YearReviewReset.fadeDuration),
            value: isActive
        )
    }
}

struct ReviewCaption: View {
    let text: Text

    var body: some View {
        text
            .font(.title3.weight(.semibold))
            .textCase(.uppercase)
            .opacity(0.75)
            .multilineTextAlignment(.center)
    }
}

struct DurationBar: View {
    let fraction: Double

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.2))
            .frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule()
                        .fill(.white)
                        .frame(width: max(8, geometry.size.width * fraction))
                }
            }
    }
}

struct YearReviewChannelImage: View {
    @Environment(\.displayScale) private var displayScale

    let channelId: String
    let images: [String: StatsChannelImage]
    let size: CGFloat

    var body: some View {
        let image = images[channelId]
        CachedImageView(imageUrl: image?.thumbnailUrl, maxPixelSize: ceil(180 * displayScale)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .opacity(0.6)
        }
        .frame(width: size, height: size)
        .channelImageClip(isPodcast: images.isPodcast(channelId))
    }
}
