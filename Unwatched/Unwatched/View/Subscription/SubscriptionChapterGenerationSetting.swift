//
//  SubscriptionChapterGenerationSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionChapterGenerationSetting: View {
    @AppStorage(Const.chapterGenerationMode) var mode = ChapterGenerationMode.off

    @Bindable var subscription: Subscription

    var body: some View {
        if mode != .off {
            CapsulePicker(
                selection: $subscription.chapterGeneration,
                options: [nil, true, false],
                label: { (text(for: $0), $0 == false ? "circle.slash" : "sparkles") },
                menuLabel: "generateChapters"
            )
            .requiresPremium(subscription.chapterGeneration == nil)
            .onChange(of: subscription.chapterGeneration) {
                ChapterAutomation.scheduleRun()
            }
        }
    }

    private func text(for value: Bool?) -> String {
        guard let value else {
            let defaultLabel = String(localized: mode.channelDefaultLabel)
            return String(localized: "defaultSegmentSetting \(defaultLabel)")
        }
        return value ? String(localized: "on") : String(localized: "off")
    }
}
