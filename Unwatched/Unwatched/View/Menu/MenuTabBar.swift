//
//  MenuTabBar.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import SwiftData
import UnwatchedShared

/// UIKit's tab bar, whose delegate lets the prominent play/pause tab refuse selection.
struct MenuTabBar: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @Environment(RefreshManager.self) var refresher

    @AppStorage(Const.showTabBarLabels) var showTabBarLabels = true
    @AppStorage(Const.showTabBarBadge) var showTabBarBadge = true

    @Query(QueueTabItemViewModifier.descriptor) var newQueueEntry: [QueueEntry]
    @Query(InboxTabItemViewModifier.descriptorAny) var anyInboxEntry: [InboxEntry]
    @Query(sort: \Tag.order) var tags: [Tag]

    @State private var playPauseHaptic = false

    var body: some View {
        let queueBadge = showTabBarBadge && !newQueueEntry.isEmpty
        MenuTabBarController(
            navManager: navManager,
            player: player,
            selection: navManager.tab,
            labels: MenuTabLabels(
                queueSymbol: QueueTabLabel.symbol(for: navManager.queueTag, in: tags),
                queueBadge: queueBadge,
                queueValue: QueueTabLabel.accessibilityValue(showBadge: queueBadge),
                inboxSymbol: InboxTabLabel.symbol(isLoading: refresher.isLoading, isEmpty: anyInboxEntry.isEmpty),
                inboxValue: InboxTabLabel.accessibilityValue(isEmpty: anyInboxEntry.isEmpty),
                isPlaying: player.isPlaying && !player.videoEnded,
                showLabels: showTabBarLabels
            ),
            onPlayPauseTapped: { playPauseHaptic.toggle() }
        )
        .sensoryFeedback(Const.sensoryFeedback, trigger: playPauseHaptic)
    }
}

struct MenuTabLabels: Equatable {
    var queueSymbol: String
    var queueBadge: Bool
    var queueValue: String
    var inboxSymbol: String
    var inboxValue: String
    var isPlaying: Bool
    var showLabels: Bool
}
#endif
