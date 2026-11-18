//
//  SubscriptionSkipSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Which end of a video the setting trims, see `ChapterService.applySkipIntro`/`applySkipOutro`.
enum SkipEdge {
    case intro
    case outro

    var label: LocalizedStringKey {
        self == .intro ? "skipIntro" : "skipOutro"
    }

    var systemImage: String {
        self == .intro ? "forward.end.circle" : "arrow.forward.to.line.circle"
    }

    var seconds: ReferenceWritableKeyPath<Subscription, Double?> {
        self == .intro ? \.skipIntroSeconds : \.skipOutroSeconds
    }
}

struct SubscriptionSkipSetting: View {
    private static let range: ClosedRange<Double> = 0...300

    var subscription: Subscription
    var edge: SkipEdge

    var body: some View {
        let seconds = Binding(
            get: {
                subscription[keyPath: edge.seconds] ?? 0
            }, set: { value in
                subscription[keyPath: edge.seconds] = value > 0 ? value : nil
            }
        )
        let isOff = seconds.wrappedValue == 0

        CapsulePicker(
            selection: seconds,
            options: Self.menuOptions(including: seconds.wrappedValue),
            label: { (Self.text(for: $0), edge.systemImage) },
            menuLabel: edge.label,
            hidesMenuValue: isOff,
            menuStep: Self.step
        )
        .requiresPremium(isOff, feature: "skipIntroOutro")
    }

    static func menuOptions(including seconds: Double) -> [Double] {
        let presets: [Double] = [0, 10, 20, 30, 60]
        return presets.contains(seconds) ? presets : (presets + [seconds]).sorted()
    }

    private static func step(_ seconds: Double, by delta: Int) -> Double? {
        let next = seconds + Double(delta)
        return range.contains(next) ? next : nil
    }

    private static func text(for seconds: Double) -> String {
        seconds > 0 ? "\(Int(seconds))s" : String(localized: "off")
    }
}

#Preview {
    SubscriptionSkipSetting(subscription: Subscription.getDummy(), edge: .intro)
}
