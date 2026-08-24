//
//  InboxView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import TipKit
import UnwatchedShared

struct InboxView: View {
    @AppStorage(Const.inboxOldestFirst) var oldestFirst: Bool = false

    @Environment(NavigationManager.self) private var navManager

    var body: some View {
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedSubscriptionInbox) {
            // the query's sort order is fixed when it's created, recreate it when the order changes
            InboxContent(oldestFirst: oldestFirst)
        }
        .tint(.neutralAccentColor)
    }
}

private struct InboxContent: View {
    @AppStorage(Const.inboxAppearance) var inboxAppearance: InboxAppearance = .cards

    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(NavigationManager.self) private var navManager
    @Environment(TinyUndoManager.self) private var undoManager

    @Query var inboxEntries: [InboxEntry]

    /// shared with `InboxCardStack` so the title can fade as the front card is dragged towards it
    @State private var cardSwipe = InboxCardSwipe()

    private var onboardingTip: OnboardingInboxTip {
        OnboardingInboxTip(appearance: inboxAppearance)
    }

    init(oldestFirst: Bool) {
        _inboxEntries = Query(InboxContent.descriptor(oldestFirst), animation: .default)
    }

    var body: some View {
        ZStack {
            MyBackgroundColor()

            if !hasEntries {
                ContentUnavailableView("noInboxItems",
                                       systemImage: "tray.fill",
                                       description: Text("noInboxItemsDescription"))
                    .contentShape(Rectangle())
                    .handleVideoUrlDrop(.inbox)
            }

            if inboxAppearance == .cards {
                // kept around while empty: undo animates the last card back from where it was thrown
                InboxCardStack(
                    entries: inboxEntries,
                    swipe: cardSwipe,
                    actionBarTip: onboardingTip
                )
            } else {
                listView
            }
        }
        .onAppear {
            navManager.setScrollId("top", ClearList.inbox.rawValue)
        }
        .onDisappear {
            Signal.log(
                "Inbox.Count",
                parameters: ["Inbox.Count.Value": Signal.bucket(inboxEntries.count)],
                throttle: .weekly
            )
        }
        .inboxToolbar()
        .myNavigationTitle("inbox", titleOpacity: { cardSwipe.titleOpacity }, titleAccessory: titleCount)
        .sendableSubscriptionDestination()
        .myTint()
    }

    /// The card stack shows one video at a time, this says how much is still ahead
    private var titleCount: Text? {
        guard inboxAppearance == .cards, hasEntries else { return nil }
        return Text(inboxEntries.count, format: .number)
            .monospacedDigit()
            .foregroundStyle(countColor)
    }

    /// `.secondary` bakes in its own translucency, which would make the count fade out well
    /// before the title as the swipe's opacity multiplies on top of it
    private var countColor: Color {
        colorScheme == .dark ? Color(white: 0.6) : Color(white: 0.4)
    }

    var listView: some View {
        // Workaround: always have the list visible, this avoids a crash when adding the last
        // inbox item to the queue and then moving the video on top of the queue
        List {
            HideShortsTipView()
                .id(NavigationManager.getScrollId("top", ClearList.inbox.rawValue))
                .listRowSeparator(.hidden)

            if hasTooManyItems {
                InboxOverflowTipView()
            }

            if hasEntries {
                InboxSwipeTipView()
                    .myListRowBackground()
                    .listRowSeparator(.hidden)
            }

            ForEach(inboxEntries) { entry in
                ZStack {
                    if let video = entry.video {
                        let videoId = video.persistentModelID
                        let youtubeId = video.youtubeId
                        let date = video.publishedDate

                        VideoListItem(
                            video,
                            video.youtubeId,
                            config: VideoListItemConfig(
                                hasInboxEntry: true,
                                isNew: video.isNew,
                                showAllStatus: false,
                                clearRole: .destructive,
                                queueRole: .destructive,
                                clearAboveBelowList: .inbox,
                                showDelete: false
                            ),
                            onChange: { reason, _ in
                                handleChange(reason, videoId, youtubeId, date)
                            }
                        )
                        .equatable()
                        .id(NavigationManager.getScrollId(video.youtubeId, ClearList.inbox.rawValue))
                        // only the topmost row, so the tip points at what's on screen
                        .popoverTip(
                            onboardingTip,
                            arrowEdge: .top,
                            isActive: entry.id == inboxEntries.first?.id
                        )
                        .tipBackgroundInteraction(.enabled)
                    } else {
                        EmptyEntry(entry)
                    }
                }
                .videoListItemEntry()
            }
            .myListRowBackground()

            if hasTooManyItems {
                HiddenEntriesInfo()
            }

            ClearAllInboxEntriesButton(
                willClearAll: willClearAll
            )
            .disabled(!hasEntries)
            .opacity(hasEntries ? 1 : 0)
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .environment(\.videoListContext, .inbox)
    }

    var hasEntries: Bool {
        !inboxEntries.isEmpty
    }

    var hasTooManyItems: Bool {
        inboxEntries.count >= (Const.inboxFetchLimit - 1)
    }

    func willClearAll() {
        let videoIds = inboxEntries.compactMap { $0.video?.persistentModelID }
        undoManager.registerAction(.moveToInbox(videoIds))
    }

    func handleChange(
        _ reason: VideoChangeReason?,
        _ videoId: PersistentIdentifier,
        _ youtubeId: String,
        _ date: Date?
    ) {
        guard let reason else {
            return
        }
        switch reason {
        case .clearEverywhere, .moveToQueue, .toggleWatched:
            undoManager.registerAction(.moveToInbox([videoId]))
        case .clearAbove:
            undoManager.handleInboxClearDirection(youtubeId, date, inboxEntries, .above)
        case .clearBelow:
            undoManager.handleInboxClearDirection(youtubeId, date, inboxEntries, .below)
        case .moveToInbox:
            break
        }
    }

    /// Oldest first fetches the oldest entries, not the newest ones in reverse
    static func descriptor(_ oldestFirst: Bool) -> FetchDescriptor<InboxEntry> {
        var descriptor = FetchDescriptor<InboxEntry>(
            sortBy: [SortDescriptor(\InboxEntry.date, order: oldestFirst ? .forward : .reverse)]
        )
        descriptor.fetchLimit = Const.inboxFetchLimit
        return descriptor
    }
}

#Preview {
    InboxView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
}
