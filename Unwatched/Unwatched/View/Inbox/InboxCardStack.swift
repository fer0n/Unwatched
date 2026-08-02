//
//  InboxCardStack.swift
//  Unwatched
//

import SwiftUI
import SwiftData
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

    @State private var awaitingRemovalIds = Set<String>()
    @State private var landedIds = Set<String>()
    @State private var flung = [FlungCard]()
    @State private var departing = [Departure]()
    @State private var commits = InboxCardCommits()
    @State private var hapticToggle = false
    @State private var deniedToggle = false

    @ScaledMetric(wrappedValue: InboxCard.Layout.baseDetailHeight) private var minDetailHeight

    /// Below this the release was a let-go, not a flick, and the card leaves the way it was dragged
    private static let flickSpeed: CGFloat = 250
    /// Mirrors `DragGesture.Value.predictedEndTranslation`
    private static let flickPrediction: CGFloat = 0.25
    private static let promoteDuration: TimeInterval = 0.2
    private static let promoteAnimation: Animation = .snappy(duration: promoteDuration)
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
            guard !awaitingRemovalIds.isEmpty else { return }
            awaitingRemovalIds.formIntersection(entries.compactMap { $0.video?.youtubeId })
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
        // a flicked card leaves the way it was thrown, one merely let go the way it was dragged
        let direction = velocity.length > Self.flickSpeed ? velocity : translation
        perform(action, video, via: "swipe", direction: direction, speed: velocity.length)
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
        let hidden = awaitingRemovalIds
            .union(departing.map(\.id))
            .union(landedIds)
        let skippedIds = commits.skippedIds
        let skipped = Set(skippedIds)
        var result = [Video]()
        var skippedVideos = [String: Video]()

        for entry in entries {
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
        let departure = Departure(video: video, target: flight.target, action: action)

        withAnimation(Self.promoteAnimation) {
            // the card carries on off screen on its own, the stack moves up behind it right away
            swipe.trigger(action)
        }
        // `departing` alone both takes the card out of the stack and flies it out, so its whole way
        // off screen belongs to this one transaction: anything else hiding it here would describe
        // the same move under the promotion's, and only one of the two can win
        withAnimation(flight.animation) {
            departing.append(departure)
        }
        withAnimation(Self.titleReturnAnimation) {
            swipe.titleOpacity = 1
        }

        commits.append(action, video, via: via)
        land(departure, after: flight.duration)
    }

    /// Takes the card out of the air once it's off screen, and runs what the swipe meant
    ///
    /// Timed rather than run off the animation's completion, which is dropped when the query
    /// updates mid-flight.
    private func land(_ departure: Departure, after duration: TimeInterval) {
        let youtubeId = departure.id
        // never before the stack behind it has settled, however hard the card was thrown
        let settled = max(duration, Self.promoteDuration)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(settled))
            // takes over holding the card back from `departing`, until the store has caught up.
            // A skip stays in the inbox and has nothing to undo.
            if departure.action != .skip {
                rememberFlung(FlungCard(youtubeId: youtubeId, offset: departure.target))
                awaitingRemovalIds.insert(youtubeId)
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
