//
//  SubscriptionEpisodeLimitSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionEpisodeLimitSetting: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    let subscription: Subscription

    @State private var pending: PendingLimit?

    var body: some View {
        CapsulePicker(
            selection: Binding(get: { subscription.episodeLimit }, set: request),
            options: [nil] + Array(Const.episodeLimits),
            label: {
                guard let limit = $0 else {
                    return (String(localized: "noEpisodeLimit"), nil)
                }
                return (String(localized: "episodeLimitEntries \(limit)"), nil)
            },
            menuLabel: "episodeLimit",
            fallbackSystemImage: "line.3.horizontal.decrease"
        )
        .alert(
            pending.map { String(localized: "episodeLimitConfirmTitle \($0.limit)") } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { pending in
            Button("setEpisodeLimit", role: .destructive) {
                apply(pending.limit)
            }
            Button("cancel", role: .cancel) { }
        } message: { pending in
            Text("episodeLimitConfirmMessage \(pending.count)")
        }
    }

    private func request(_ limit: Int?) {
        let count = videosOverLimit(limit).count
        if let limit, count > 0 {
            pending = PendingLimit(limit: limit, count: count)
        } else {
            apply(limit)
        }
    }

    private func apply(_ limit: Int?) {
        EpisodeLimitService.clear(videosOverLimit(limit), in: modelContext)
        subscription.episodeLimit = limit
        try? modelContext.save()
    }

    private func videosOverLimit(_ limit: Int?) -> [Video] {
        EpisodeLimitService.videosOverLimit(limit, of: subscription, exempt: player.video?.youtubeId, in: modelContext)
    }

    private struct PendingLimit {
        let limit: Int
        let count: Int
    }
}
