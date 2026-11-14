//
//  SubscriptionEpisodeLimitSetting.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct PendingEpisodeLimit {
    let limit: Int
    let count: Int
}

struct SubscriptionEpisodeLimitSetting: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    let subscription: Subscription
    @Binding var pending: PendingEpisodeLimit?

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
    }

    private func request(_ limit: Int?) {
        let count = EpisodeLimitService.videosOverLimit(
            limit, of: subscription, exempt: player.video?.youtubeId, in: modelContext
        ).count
        if let limit, count > 0 {
            pending = PendingEpisodeLimit(limit: limit, count: count)
        } else {
            Self.apply(limit, to: subscription, exempt: player.video?.youtubeId, in: modelContext)
        }
    }

    static func apply(_ limit: Int?, to subscription: Subscription, exempt: String?, in modelContext: ModelContext) {
        let videos = EpisodeLimitService.videosOverLimit(limit, of: subscription, exempt: exempt, in: modelContext)
        EpisodeLimitService.clear(videos, in: modelContext)
        subscription.episodeLimit = limit
        try? modelContext.save()
    }
}

struct EpisodeLimitConfirmation: ViewModifier {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    let subscription: Subscription
    @Binding var pending: PendingEpisodeLimit?

    func body(content: Content) -> some View {
        content.alert(
            pending.map { String(localized: "episodeLimitConfirmTitle \($0.limit)") } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { pending in
            Button("setEpisodeLimit", role: .destructive) {
                SubscriptionEpisodeLimitSetting.apply(
                    pending.limit,
                    to: subscription,
                    exempt: player.video?.youtubeId,
                    in: modelContext
                )
            }
            Button("cancel", role: .cancel) { }
        } message: { pending in
            Text("episodeLimitConfirmMessage \(pending.count)")
        }
    }
}
