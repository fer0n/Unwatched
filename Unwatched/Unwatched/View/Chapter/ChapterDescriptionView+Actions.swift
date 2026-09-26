//
//  ChapterDescriptionView+Actions.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

extension ChapterDescriptionView {
    #if os(macOS)
    // same order as InboxCardAction
    var actionBar: some View {
        HStack(spacing: 12) {
            detailButton(Const.queueNextSF, label: "queueNext", action: addToQueueNext)
            detailButton(Const.queueLastSF, label: "queueLast", action: addToQueueLast)
            detailButton(Const.clearNoFillSF, label: clearLabel, disabled: !canBeCleared, action: clearVideo)
        }
        .padding(15)
        .padding()
    }

    private func detailButton(
        _ systemImage: String,
        label: LocalizedStringKey,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: buttonSize * 0.4, weight: .semibold))
                .foregroundStyle(Color.neutralAccentColor)
                .frame(width: buttonSize, height: buttonSize)
                .detailActionGlass()
                .opacity(disabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .disabled(disabled)
        .accessibilityLabel(label)
    }
    #else
    @ToolbarContentBuilder
    var actionToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("queueNext", systemImage: Const.queueNextSF, action: addToQueueNext)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("queueLast", systemImage: Const.queueLastSF, action: addToQueueLast)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if video.inboxEntry == nil {
                    Button("moveToInbox", systemImage: "tray.and.arrow.down", action: moveToInbox)
                }
                if canBeCleared {
                    Button(clearLabel, systemImage: Const.clearNoFillSF, action: clearVideo)
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("moreOptions")
        }
    }
    #endif

    var playButton: some View {
        Button(action: playVideo) {
            Image(systemName: "play.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.neutralAccentColor)
                .frame(width: 34, height: 34)
                .detailActionGlass()
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .accessibilityLabel("play")
    }

    var canBeCleared: Bool {
        video.inboxEntry != nil || video.queueEntry != nil
    }

    /// Names the list the video leaves; a video in both keeps the generic label
    var clearLabel: LocalizedStringKey {
        switch (video.inboxEntry != nil, video.queueEntry != nil) {
        case (true, false): "removeFromInbox"
        case (false, true): "removeFromQueue"
        default: "clearVideo"
        }
    }

    func playVideo() {
        navManager.popVideoDetail()
        VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
        player.playVideo(video)
        Signal.videoAction("play", .detail)
        Signal.playbackStarted("detail")
        navManager.handlePlay()
    }

    func addToQueueNext() {
        let requiresQueueChange = requiresQueueChange(adding: true)
        VideoService.insertQueueEntries(
            at: 1,
            videos: [video],
            filter: navManager.queueFilter(modelContext),
            modelContext: modelContext
        )
        if requiresQueueChange {
            handlePotentialQueueChange()
        }
        Signal.videoAction("queueTop", .detail)
        handleDone(undo: .moveToInbox([video.persistentModelID]))
    }

    func addToQueueLast() {
        let requiresQueueChange = requiresQueueChange(adding: true)
        VideoService.addToBottomQueue(
            video: video,
            modelContext: modelContext
        )
        if requiresQueueChange {
            handlePotentialQueueChange()
        }
        Signal.videoAction("queueBottom", .detail)
        handleDone(undo: .moveToInbox([video.persistentModelID]))
    }

    func clearVideo() {
        let requiresQueueChange = requiresQueueChange()
        VideoService.clearEntries(from: video, modelContext: modelContext)
        if requiresQueueChange {
            handlePotentialQueueChange()
        }
        Signal.videoAction("clear", .detail)
        handleDone(undo: .moveToInbox([video.persistentModelID]))
    }

    func moveToInbox() {
        let requiresQueueChange = requiresQueueChange()
        let undo: UndoAction? = video.queueEntry.map {
            .restoreToQueue(video.persistentModelID, order: $0.order)
        }
        VideoService.moveVideoToInbox(video, modelContext: modelContext)
        if requiresQueueChange {
            handlePotentialQueueChange()
        }
        Signal.videoAction("inbox", .detail)
        handleDone(undo: undo)
    }

    func handlePotentialQueueChange() {
        player.loadTopmostVideoFromQueue()
    }

    func requiresQueueChange(adding: Bool = false) -> Bool {
        if player.isTopOfQueue(order: video.queueEntry?.order, modelContext) {
            return true
        }
        return adding && player.isQueueEmpty(modelContext)
    }

    func handleDone(undo: UndoAction?) {
        if let undo {
            undoManager.registerAction(undo)
        }
        hapticToggle.toggle()
        if navManager.tab == .inbox, let date = video.publishedDate {
            openNextInboxVideo(date)
        } else {
            dismiss()
        }
    }

    func openNextInboxVideo(_ date: Date) {
        var descriptor = FetchDescriptor<InboxEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = Const.inboxFetchLimit

        guard let entries = try? modelContext.fetch(descriptor), !entries.isEmpty else {
            dismiss()
            return
        }

        if let nextEntry = entries.first(where: { ($0.date ?? Date.distantFuture) < date }),
           let nextVideo = nextEntry.video {
            navManager.replaceInboxVideoDetail(with: nextVideo)
        } else if let firstEntry = entries.first, let firstVideo = firstEntry.video {
            navManager.replaceInboxVideoDetail(with: firstVideo)
        } else {
            dismiss()
        }
    }
}

private extension View {
    @ViewBuilder
    func detailActionGlass() -> some View {
        #if os(visionOS)
        background(.ultraThinMaterial, in: .circle)
        #else
        glassEffect(.regular.interactive(), in: .circle)
        #endif
    }
}
