//
//  InboxCardStack.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import TipKit
import UnwatchedShared

/// The inbox as a stack of cards, most recent video on top
struct InboxCardStack: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerManager.self) private var player
    @Environment(TinyUndoManager.self) private var undoManager
    @Environment(SheetPositionReader.self) private var sheetPos
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let entries: [InboxEntry]
    /// shared with the parent, which fades the navigation title as the front card is dragged
    var swipe = InboxCardSwipe()

    /// Anchored on the action bar: the stack fills the sheet, so a popover hanging off it would
    /// end up at the bottom of the screen instead of on the card
    var actionBarTip: (any Tip)?

    /// Entries whose card has left, held back until the query has caught up with the write.
    /// Keyed by the entry rather than by the video: undoing a swipe files the video under a new
    /// inbox entry, and that one was never swiped away — an id left over from the old one has
    /// nothing to say about it.
    @State private var awaitingRemovalEntryIds = Set<PersistentIdentifier>()
    @State private var landedIds = Set<String>()
    @State private var flung = [FlungCard]()
    @State private var departing = [Departure]()
    @State private var commits = InboxCardCommits()
    @State private var hapticToggle = false
    @State private var deniedToggle = false

    @ScaledMetric(wrappedValue: InboxCard.Layout.baseDetailHeight) private var minDetailHeight

    /// Below this the release was a let-go, not a flick, and the card leaves the way it was dragged
    private static let letGoSpeed: CGFloat = 120
    /// Above this the throw alone says where the card goes
    private static let flickSpeed: CGFloat = 500
    /// Mirrors `DragGesture.Value.predictedEndTranslation`
    private static let flickPrediction: CGFloat = 0.25
    /// The stack behind moves up on the flight's own animation; the hardest flick is still too
    /// short to tear the card out over
    private static let minSettleDuration: TimeInterval = 0.2
    private static let titleReturnAnimation: Animation = .easeInOut(duration: 0.4).delay(0.1)
    private static let maxFlung = 10
    /// one more than is ever visible, so the next card is built before it moves up
    private static let stackDepth = 3

    var body: some View {
        let videos = visibleVideos
        let frontId = videos.first?.youtubeId

        GeometryReader { geo in
            // iPad sidebar and iPhone landscape genuinely differ in height by orientation;
            // only the portrait iPhone sheet needs flooring against its own drag jitter
            let isFixedPortraitSheet = !Device.isBigScreen(horizontalSizeClass) && verticalSizeClass != .compact
            let minHeight = isFixedPortraitSheet ? sheetPos.playerControlHeight : 0
            let available = CGSize(width: geo.size.width, height: max(geo.size.height, minHeight))
            let layout = InboxCard.Layout(available: available, minDetailHeight: minDetailHeight)

            ZStack(alignment: .bottom) {
                ZStack {
                    // one `ForEach`, so a thrown card carries on as the same view instead of being
                    // rebuilt into a second one. Cards in flight go last and stay last, so none of
                    // them changes place — a `zIndex` isn't re-applied to a card that does.
                    ForEach(slots(videos), id: \.id) { slot in
                        card(slot, layout: layout, frontId: frontId)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // the whole stack recognizes, so a card leaving mid-swipe can't hand the next
                // one to the sheet behind it
                .inboxCardDrag(
                    isEnabled: !videos.isEmpty,
                    onChange: { drag(videos, to: $0) },
                    onEnd: { endDrag(videos, $0, $1) }
                )

                InboxCardActionBar(
                    swipe: swipe,
                    perform: { perform($0, videos.first, via: "button") }
                )
                // the bar belongs under the details, not across the thumbnail
                .padding(.leading, layout.isHorizontal ? layout.mediaSize.width : 0)
                .padding(.bottom, InboxCardActionBar.bottomPadding)
                // stays while the last card is still in the air
                .opacity(videos.isEmpty && departing.isEmpty ? 0 : 1)
                .allowsHitTesting(!videos.isEmpty)
                .popoverTip(actionBarTip, arrowEdge: .bottom, isActive: !videos.isEmpty)
            }
            .frame(width: layout.size.width)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal)
        .padding(.bottom, 13)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .sensoryFeedback(Const.deniedFeedback, trigger: deniedToggle)
        .onChange(of: videos.count, initial: true) {
            swipe.setSkipDisabled(videos.count <= 1)
        }
        .onChange(of: entries) {
            guard !awaitingRemovalEntryIds.isEmpty else { return }
            awaitingRemovalEntryIds.formIntersection(entries.map(\.persistentModelID))
        }
        // an undo has to find the swipe it is meant to take back already registered
        .onAppear { undoManager.willUndo = commitPending }
        .onDisappear {
            undoManager.willUndo = nil
            // nothing is left to wait for the writes with
            commitPending()
        }
    }

    private func commitPending() {
        commits.flush(modelContext, player, undoManager)
    }

    /// Every card the stack draws, back to front
    private func slots(_ videos: [Video]) -> [Slot] {
        videos.enumerated().reversed().map { depth, video in
            Slot(video: video, placement: .stack(depth: depth, flung: flungOffset(video)))
        } + departing.map {
            Slot(video: $0.video, placement: .departing(offset: $0.target))
        }
    }

    private func card(_ slot: Slot, layout: InboxCard.Layout, frontId: String?) -> some View {
        InboxCard(video: slot.video, layout: layout)
            .equatable()
            .modifier(InboxCardTransform(swipe: swipe, frontId: frontId, placement: slot.placement))
            .onAppear { returnFlungCard(slot.video, animated: slot.placement.depth == 0) }
            // the query animates its updates, a card must never fade in over the one behind it
            .transition(.identity)
    }

    private func drag(_ videos: [Video], to translation: CGSize) {
        // the card the swipe started on, the stack may have moved on underneath a flick
        guard let youtubeId = swipe.drag?.youtubeId ?? videos.first?.youtubeId else { return }
        swipe.setDrag(youtubeId, to: translation)
    }

    private func endDrag(_ videos: [Video], _ translation: CGSize, _ velocity: CGSize) {
        let predicted = translation + velocity * Self.flickPrediction
        let triggered = translation.length > InboxCardAction.triggerDistance
            || predicted.length > InboxCardAction.flickDistance
        let video = videos.first { $0.youtubeId == swipe.drag?.youtubeId }

        guard triggered, let video, let action = InboxCardAction(translation: translation) else {
            withAnimation(.bouncy) {
                swipe.reset()
            }
            return
        }
        let heading = Self.heading(translation, velocity)
        perform(
            action,
            video,
            via: "swipe",
            direction: heading,
            // the flight goes along `heading`; speed across it is not speed along it, and would
            // throw the card out faster than it was ever travelling that way
            speed: max(0, velocity.projected(on: heading))
        )
    }

    /// Where the card was going when it was let go
    ///
    /// A flick leaves the way it was thrown, one merely let go the way it was dragged. In between
    /// the two are blended: the speed a finger is read at as it leaves the glass is jittery, so at
    /// a single cutoff two otherwise identical swipes head off in different directions.
    private static func heading(_ translation: CGSize, _ velocity: CGSize) -> CGSize {
        let range = flickSpeed - letGoSpeed
        let thrown = min(1, max(0, (velocity.length - letGoSpeed) / range))
        let blended = translation.normalized * (1 - thrown) + velocity.normalized * thrown
        // a finger that reverses as it lifts can cancel the two out; the drag is never zero here
        return blended.length > 0.01 ? blended.normalized : translation.normalized
    }

    private func flungOffset(_ video: Video) -> CGSize {
        flung.first { $0.youtubeId == video.youtubeId }?.offset ?? .zero
    }

    /// Animated by hand: undoing renumbers the queue, and those updates cut a transition short
    private func returnFlungCard(_ video: Video, animated: Bool) {
        guard flung.contains(where: { $0.youtubeId == video.youtubeId }) else { return }
        // a turn later, so the card is on screen at its offset before it starts moving
        Task { @MainActor in
            withAnimation(animated ? .snappy(duration: 0.4) : nil) {
                flung.removeAll { $0.youtubeId == video.youtubeId }
            }
        }
    }

    /// A card that was swiped away, kept so undo can throw it back the way it left
    private struct FlungCard {
        let youtubeId: String
        let offset: CGSize
    }

    /// The videos the stack keeps around, skipped ones last
    private var visibleVideos: [Video] {
        let hidden = Set(departing.map(\.id)).union(landedIds)
        let skippedIds = commits.skippedIds
        let skipped = Set(skippedIds)
        var result = [Video]()
        var skippedVideos = [String: Video]()

        for entry in entries {
            guard !awaitingRemovalEntryIds.contains(entry.persistentModelID) else { continue }
            guard let video = entry.video, !hidden.contains(video.youtubeId) else { continue }
            guard !skipped.contains(video.youtubeId) else {
                skippedVideos[video.youtubeId] = video
                continue
            }
            result.append(video)
            if result.count == Self.stackDepth {
                return result
            }
        }
        let refill = skippedIds.compactMap { skippedVideos[$0] }
        return result + refill.prefix(Self.stackDepth - result.count)
    }

    private func perform(
        _ action: InboxCardAction,
        _ video: Video?,
        via: String,
        direction: CGSize? = nil,
        speed: CGFloat = 0
    ) {
        guard let video, !departing.contains(where: { $0.id == video.youtubeId }) else { return }
        // the card was dragged all the way, it still goes back where it came from
        guard !swipe.isDisabled(action) else {
            deniedToggle.toggle()
            withAnimation(.bouncy) {
                swipe.reset()
            }
            return
        }
        hapticToggle.toggle()

        let flight = InboxCardFlight(
            from: swipe.translation(of: video.youtubeId),
            towards: direction ?? action.direction,
            speed: speed
        )
        let departure = Departure(
            video: video,
            entryId: video.inboxEntry?.persistentModelID,
            target: flight.target,
            action: action
        )

        // `departing` alone both takes the card out of the stack and flies it out, and letting go
        // of the drag describes the very same move — in a transaction of its own it is a second
        // answer to where the card is, and the one that wins is anyone's guess. One transaction,
        // one answer. The stack behind doesn't need the drag cleared to move up: it reads the
        // translation of whichever card is at the front, and that is the next one from here on.
        withAnimation(flight.animation) {
            swipe.trigger(action)
            departing.append(departure)
        }
        withAnimation(Self.titleReturnAnimation) {
            swipe.titleOpacity = 1
        }

        commits.append(action, video, via: via)
        // the write waits for the card to land, the undo button must not. A skip stays in the
        // inbox and has nothing to take back.
        if action != .skip {
            undoManager.setHasPendingAction(true)
        }
        land(departure, after: flight.duration)
    }

    /// Takes the card out of the air once it's off screen, and runs what the swipe meant
    ///
    /// Timed rather than run off the animation's completion, which is dropped when the query
    /// updates mid-flight.
    private func land(_ departure: Departure, after duration: TimeInterval) {
        let youtubeId = departure.id
        // never before the stack behind it has settled, however hard the card was thrown
        let settled = max(duration, Self.minSettleDuration)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(settled))
            // takes over holding the card back from `departing`, until the store has caught up.
            // A skip stays in the inbox and has nothing to undo.
            if departure.action != .skip {
                rememberFlung(FlungCard(youtubeId: youtubeId, offset: departure.target))
                if let entryId = departure.entryId {
                    awaitingRemovalEntryIds.insert(entryId)
                }
            }
            departing.removeAll { $0.id == youtubeId }
            // one more turn, so a skipped card is torn down before it comes back at the very back
            // of the stack, rather than changing place within the `ForEach`
            landedIds.insert(youtubeId)
            Task { @MainActor in
                landedIds.remove(youtubeId)
            }
            // quick swipes wait for the last of them: a save during the next card's flight is
            // the very thing holding it back was for
            if departing.isEmpty {
                commitPending()
            }
        }
    }

    private func rememberFlung(_ card: FlungCard) {
        flung.removeAll { $0.youtubeId == card.youtubeId }
        flung.append(card)
        if flung.count > Self.maxFlung {
            flung.removeFirst(flung.count - Self.maxFlung)
        }
    }

    /// A card in the stack or in the air, as it is drawn
    private struct Slot {
        let video: Video
        let placement: InboxCardPlacement

        var id: String { video.youtubeId }
    }

    /// A card that was thrown, on its way off screen above the stack
    private struct Departure: Identifiable {
        let video: Video
        /// The inbox entry the card was showing, the one the swipe is about to delete
        let entryId: PersistentIdentifier?
        let target: CGSize
        let action: InboxCardAction

        var id: String { video.youtubeId }
    }
}

#Preview {
    let container = DataProvider.previewContainer
    let context = ModelContext(container)

    let videos = [Video.getDummy(), Video.getDummyNonEmbedding()]
    for (index, video) in videos.enumerated() {
        context.insert(video)
        let chapters = [
            Chapter(title: "Intro", time: 0, duration: 30),
            Chapter(title: "Main", time: 30, duration: 60),
            Chapter(title: "Outro", time: 90, duration: 20)
        ]
        chapters.forEach { context.insert($0) }
        video.chapters = chapters
        video.duration = 110
        let entry = InboxEntry(video, video.publishedDate)
        entry.date = Calendar.current.date(byAdding: .day, value: -index, to: .now)
        context.insert(entry)
    }
    try? context.save()

    let entries = (try? context.fetch(FetchDescriptor<InboxEntry>())) ?? []

    return ZStack {
        Color.backgroundColor
            .ignoresSafeArea(.all)
        InboxCardStack(entries: entries)
    }
    .modelContainer(container)
    .environment(NavigationManager())
    .environment(PlayerManager())
    .environment(ImageCacheManager())
    .environment(TinyUndoManager())
}
