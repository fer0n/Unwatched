//
//  SubscriptionAutoSkipSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// The chapter titles this channel skips automatically, and a way to stop skipping one.
struct SubscriptionAutoSkipSetting: View {
    @PremiumCloudStorage(Const.autoSkipRecurringChapters) var autoSkipRecurringChapters = true

    var subscription: Subscription

    var body: some View {
        let titles = subscription.autoSkipChapterTitles ?? []

        if autoSkipRecurringChapters, !titles.isEmpty {
            Menu {
                Section("autoSkipChaptersHelper") {
                    ForEach(titles, id: \.self) { title in
                        Button(title, role: .destructive) {
                            subscription.setAutoSkip(title, false)
                        }
                        #if !os(macOS)
                        .menuActionDismissBehavior(.disabled)
                        #endif
                    }
                }
            } label: {
                CapsuleMenuLabel(
                    systemImage: "forward.circle.fill",
                    menuLabel: "autoSkipChapters",
                    text: "\(titles.count)"
                )
            }
            .menuIndicator(.hidden)
            .buttonStyle(CapsuleButtonStyle(primary: false))
        }
    }
}
