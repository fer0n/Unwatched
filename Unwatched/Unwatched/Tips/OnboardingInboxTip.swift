//
//  OnboardingInboxTip.swift
//  Unwatched
//

import SwiftUI
import TipKit
import UnwatchedShared

/// Explains what to do with an inbox video, shown on the first list row right after onboarding.
struct OnboardingInboxTip: Tip {
    var title: Text {
        Text("onboardingInboxTip")
    }

    var message: Text? {
        let newline = Text(verbatim: "\n")
        return Self.joined([
            Text("onboardingInboxTipMessage"), newline,
            iconLine(Const.queueNextSF, "onboardingInboxTipQueueNext"), newline,
            iconLine(Const.queueLastSF, "onboardingInboxTipQueueLast"), newline,
            iconLine(Const.clearNoFillSF, "onboardingInboxTipClear")
        ])
    }

    // the icon is a run inside the message's single `Text`, so color and weight are all it can take
    private func iconLine(_ systemImage: String, _ text: String.LocalizationValue) -> Text {
        Self.joined([
            Text(Image(systemName: systemImage))
                .bold()
                .foregroundStyle(Color.primary),
            Text(verbatim: "  "),
            Text(String(localized: text))
        ])
    }

    // built without a string literal: an interpolated literal would leak format strings into the catalog
    private static func joined(_ parts: [Text]) -> Text {
        var interpolation = LocalizedStringKey.StringInterpolation(literalCapacity: 0, interpolationCount: parts.count)
        for part in parts {
            interpolation.appendInterpolation(part)
        }
        return Text(LocalizedStringKey(stringInterpolation: interpolation))
    }

    @Parameter
    static var onboardingFinished: Bool = false

    var rules: [Rule] {
        [
            #Rule(Self.$onboardingFinished) { $0 == true }
        ]
    }
}

/// TipKit decides asynchronously whether to hand the tip to its `TipView`, so this needs a live
/// canvas — a still of the first frame shows nothing but the background. Use `Message layout` then.
#Preview("Tip") {
    TipView(OnboardingInboxTip())
        .tipBackground(Color.insetBackgroundColor)
        // roughly the width a tip popover gets on an iPhone
        .frame(width: 300)
        .padding()
        .tint(ThemeColor().color)
        .task {
            try? Tips.resetDatastore()
            try? Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
            Tips.showAllTipsForTesting()
        }
}

/// The composed text without TipKit, so it draws on the first frame: shows the line breaks
#Preview("Message layout") {
    let tip = OnboardingInboxTip()
    VStack(alignment: .leading, spacing: 4) {
        tip.title
            .font(.headline)
        tip.message
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .frame(width: 280, alignment: .leading)
    .padding()
}
