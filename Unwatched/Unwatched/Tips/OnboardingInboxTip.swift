//
//  OnboardingInboxTip.swift
//  Unwatched
//

import SwiftUI
import TipKit
import UnwatchedShared

/// Explains what to do with an inbox video, shown on the first card right after onboarding.
struct OnboardingInboxTip: Tip {
    /// Only the card stack can skip, so the list gets the action lines without that one
    var appearance: InboxAppearance = .cards

    var title: Text {
        Text("onboardingInboxTip")
    }

    // concatenated rather than interpolated: interpolation leaks format strings into the catalog
    var message: Text? {
        var lines = [
            iconLine(Const.queueNextSF, "onboardingInboxTipQueueNext"),
            iconLine(Const.queueLastSF, "onboardingInboxTipQueueLast")
        ]
        if appearance == .cards {
            lines.append(iconLine(InboxCardAction.skip.systemImage, "onboardingInboxTipSkip"))
        }
        lines.append(iconLine(Const.clearNoFillSF, "onboardingInboxTipClear"))

        return lines.reduce(Text("onboardingInboxTipMessage") + Text(verbatim: "\n")) {
            $0 + Text(verbatim: "\n") + $1
        }
    }

    // the icon is a run inside the message's single `Text`, so color and weight are all it can take
    private func iconLine(_ systemImage: String, _ text: String.LocalizationValue) -> Text {
        Text(Image(systemName: systemImage))
            .bold()
            .foregroundStyle(Color.primary)
            + Text(verbatim: "  ")
            + Text(String(localized: text))
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
    VStack(spacing: 20) {
        ForEach([InboxAppearance.cards, .list], id: \.self) { appearance in
            TipView(OnboardingInboxTip(appearance: appearance))
                .tipBackground(Color.insetBackgroundColor)
        }
    }
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
    VStack(alignment: .leading, spacing: 20) {
        ForEach([InboxAppearance.cards, .list], id: \.self) { appearance in
            let tip = OnboardingInboxTip(appearance: appearance)
            VStack(alignment: .leading, spacing: 4) {
                tip.title
                    .font(.headline)
                tip.message
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .frame(width: 280, alignment: .leading)
    .padding()
}
