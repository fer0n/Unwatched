//
//  TagEditChannels.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct TagBadge: Identifiable, Hashable {
    let id: PersistentIdentifier
    let name: String
    let symbol: String
}

struct ChannelsSection: View {
    let title: LocalizedStringKey
    let subscriptions: [Subscription]
    let otherTagsBySubscription: [PersistentIdentifier: [TagBadge]]
    let isCovered: (Subscription) -> Bool
    let toggle: (Subscription) -> Void

    private var selectedSubscriptions: [Subscription] {
        subscriptions.filter(isCovered)
    }

    private var remainingSubscriptions: [Subscription] {
        subscriptions.filter { !isCovered($0) }
    }

    var body: some View {
        MySection(title) {
            if subscriptions.isEmpty {
                Text("noSubscriptions")
                    .foregroundStyle(.secondary)
            }
            rows(for: selectedSubscriptions)
        }

        if !remainingSubscriptions.isEmpty {
            MySection {
                rows(for: remainingSubscriptions)
            }
        }
    }

    @ViewBuilder
    private func rows(for subscriptions: [Subscription]) -> some View {
        ForEach(subscriptions, id: \.persistentModelID) { subscription in
            Button {
                toggle(subscription)
            } label: {
                ChannelRow(
                    title: subscription.displayTitle,
                    otherTags: otherTagsBySubscription[subscription.persistentModelID] ?? [],
                    isCovered: isCovered(subscription)
                )
            }
        }
    }
}

private struct ChannelRow: View {
    let title: String
    let otherTags: [TagBadge]
    let isCovered: Bool

    var body: some View {
        HStack {
            Text(title)
                .lineLimit(1)
                .foregroundStyle(Color.neutralAccentColor)
            Spacer()
            // Color.secondary, not .secondary: inside a row button the hierarchical
            // style renders as a lighter tint, not grey
            ForEach(otherTags) { other in
                Image(systemName: other.symbol)
                    .foregroundStyle(Color.secondary)
                    .accessibilityLabel(other.name)
            }
            if isCovered {
                Image(systemName: Const.checkmarkSF)
            }
        }
    }
}

/// The videos the tag names on top of its channels, behind a count. Only ever shows what is already
/// there: adding happens from a video's own menu, where the user is looking at the video rather than
/// at a list of every video the app knows.
struct TaggedVideosSection: View {
    let title: LocalizedStringKey
    let tag: Tag
    let videos: [Video]

    var body: some View {
        MySection {
            NavigationLink {
                TaggedVideosList(title: title, tag: tag)
            } label: {
                HStack {
                    Text(title)
                        .foregroundStyle(Color.neutralAccentColor)
                    Spacer()
                    Text(verbatim: "\(videos.count)")
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }
}
