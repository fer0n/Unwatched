//
//  ChapterSelection.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct ChapterDescriptionView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(TinyUndoManager.self) private var undoManager

    @State var hapticToggle = false
    @State var transcriptVM = TranscriptView.ViewModel()

    static let buttonSize: CGFloat = 46
    @ScaledMetric(wrappedValue: buttonSize) private var buttonSizeScaled: CGFloat

    let video: Video
    var bottomSpacer: CGFloat = 0
    var isCompact = false
    var scrollToCurrent = false
    var isTransparent = false
    var showThumbnail = true
    var showActions = true

    var body: some View {
        let hasChapters = video.sortedChapterData.isEmpty == false

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
                    if showThumbnail {
                        VideoDetailThumbnail(video: video)
                            .padding([.top, .horizontal], -5)
                    }

                    DescriptionDetailHeaderView(
                        video: video,
                        onTitleTap: onTitleTap)

                    if hasChapters {
                        ChapterList(
                            video: video,
                            isCompact: isCompact,
                            isTransparent: isTransparent
                        )
                        .padding(.top)
                        .padding(.bottom, 5)
                    }

                    let hasTranscript = TranscriptDescriptionSelection.canHaveTranscript(
                        video,
                        isCurrentVideo: isCurrentVideo,
                        transcriptUrl: player.transcriptUrl
                    )

                    if hasTranscript || hasChapters {
                        ChapterSettingsMenu(video: player.video)

                        Spacer()
                            .frame(height: 10)
                    }

                    if showGenerateTranscript {
                        // no transcript means no chapters can be generated, so the picker gives way to just the
                        // button — the settings menu above still stands when chapters already exist regardless
                        GenerateTranscriptButton(video: video, viewModel: $transcriptVM)
                            .transition(.opacity)

                        Spacer()
                            .frame(height: 10)

                        DescriptionDetailView(description: video.videoDescription)
                    } else {
                        TranscriptDescriptionSelection(
                            video: video,
                            isCurrentVideo: isCurrentVideo,
                            scrollProxy: proxy,
                            transcriptVM: $transcriptVM
                        )
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, showThumbnail ? 15 : isCompact ? 10 : 20)
                .padding(.top, showThumbnail ? 15 : isCompact ? 15 : 30)
                .frame(idealWidth: 500, maxWidth: 800, alignment: .leading)
                .animation(.easeInOut, value: showGenerateTranscript)

                Spacer()
                    .frame(height: bottomSpacer)

                Spacer()
                    .frame(maxWidth: .infinity)
            }
            .task(id: video.youtubeId) {
                // checked eagerly (not just on opening the transcript tab) since a podcast episode without one hides
                // chapters/description/transcript entirely in favor of the generate-transcript button
                guard video.isPodcast, TranscriptService.canGenerateTranscript else { return }
                await transcriptVM.handleTranscriptLoading(video, nil)
                // kept running for the lifetime of this screen so a generation started elsewhere — a Shortcut,
                // say — still shows its progress here and loads the result once it lands
                await transcriptVM.watchGeneration(for: video)
            }
            .onAppear {
                scrollToChapterIfNeeded(hasChapters: hasChapters, proxy: proxy)
            }
            // the podcast layout keeps both player pages mounted (see `PlayerContentView.livePages`),
            // so switching to this one never re-triggers `onAppear`
            .onPlayerTabChange {
                scrollToChapterIfNeeded(hasChapters: hasChapters, proxy: proxy)
            }
            .if(showActions) { view in
                Group {
                    #if os(macOS)
                    view.overlay {
                        actionOverlay
                    }
                    #else
                    view.toolbar {
                        let placement: ToolbarItemPlacement = Device.isVision ? .topBarTrailing : .bottomBar

                        ToolbarItem(placement: placement) {
                            detailButton(Const.queueNextSF, label: "queueNext", withBackground: false) {
                                addToQueueNext()
                                Signal.videoAction("queueTop", .detail)
                            }
                        }

                        FixedToolbarSpacer(placement: placement)

                        ToolbarItem(placement: placement) {
                            detailButton(Const.queueLastSF, label: "queueLast", withBackground: false) {
                                addToQueueLast()
                                Signal.videoAction("queueBottom", .detail)
                            }
                        }
                        FixedToolbarSpacer(placement: placement)

                        ToolbarItem(placement: placement) {
                            detailButton("play.fill", label: "play", withBackground: false) {
                                playVideo()
                                Signal.videoAction("play", .detail)
                            }
                        }
                        FixedToolbarSpacer(placement: placement)

                        ToolbarItem(placement: placement) {
                            detailButton(
                                Const.clearNoFillSF,
                                label: "clearVideo",
                                disabled: !canBeCleared,
                                withBackground: false
                            ) {
                                clearVideo()
                                Signal.videoAction("clear", .detail)
                            }
                        }
                    }
                    #endif
                }
            }
            .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
            #if os(visionOS)
            .myTint(neutral: true)
            #endif
        }
        .tint(.neutralAccentColor)
    }

    /// Same order as the inbox card actions (see `InboxCardAction`)
    @ViewBuilder
    var buttons: some View {
        detailButton(Const.queueNextSF, label: "queueNext") {
            addToQueueNext()
            Signal.videoAction("queueTop", .detail)
        }

        detailButton(Const.queueLastSF, label: "queueLast") {
            addToQueueLast()
            Signal.videoAction("queueBottom", .detail)
        }

        detailButton("play.fill", label: "play") {
            playVideo()
            Signal.videoAction("play", .detail)
        }

        detailButton(Const.clearNoFillSF, label: "clearVideo", disabled: !canBeCleared) {
            clearVideo()
            Signal.videoAction("clear", .detail)
        }
    }

    /// `withBackground` is `false` inside the native toolbar (iOS/visionOS), which already renders
    /// each `ToolbarItem` as its own glass circle when separated by a `ToolbarSpacer` — adding our
    /// own background there doubles up the circle.
    private func detailButton(
        _ systemImage: String,
        label: LocalizedStringKey,
        disabled: Bool = false,
        withBackground: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: buttonSizeScaled * 0.4, weight: .semibold))
                .foregroundStyle(Color.neutralAccentColor)
                .frame(width: buttonSizeScaled, height: buttonSizeScaled)
                .if(withBackground) { $0.detailActionGlass() }
                .opacity(disabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    var actionOverlay: some View {
        HStack(spacing: 12) {
            buttons
        }
        .padding(15)
        .frame(maxHeight: .infinity, alignment: .bottom)
        #if os(macOS)
        .padding()
        #endif
    }

    var canBeCleared: Bool {
        video.inboxEntry != nil || video.queueEntry != nil
    }

    var isCurrentVideo: Bool {
        video.youtubeId == player.video?.youtubeId
    }

    /// A podcast episode that has no transcript at all — not one that was published, not one generated before — hides
    /// the description/transcript picker in favor of just the button.
    var showGenerateTranscript: Bool {
        video.isPodcast
            && TranscriptService.canGenerateTranscript
            && transcriptVM.transcript?.isEmpty == true
    }

    func playVideo() {
        VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
        player.playVideo(video)
        Signal.playbackStarted("detail")
        navManager.handlePlay()
    }

    func addToQueueNext() {
        let requiresQueueChange = requiresQueueChange(adding: true)
        VideoService.insertQueueEntries(
            at: 1,
            videos: [video],
            modelContext: modelContext
        )
        if requiresQueueChange {
            handlePotentialQueueChange()
        }
        handleDone()
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
        handleDone()
    }

    func clearVideo() {
        let requiresQueueChange = requiresQueueChange()
        VideoService.clearEntries(from: video, modelContext: modelContext)
        if requiresQueueChange {
            handlePotentialQueueChange()
        }
        handleDone()
    }

    func handlePotentialQueueChange() {
        player.loadTopmostVideoFromQueue()
    }

    /// - Parameter adding: pass `true` when the video is about to be queued; filling an empty queue
    /// makes it the new top video, whichever index it goes in at
    func requiresQueueChange(adding: Bool = false) -> Bool {
        if player.isTopOfQueue(order: video.queueEntry?.order, modelContext) {
            return true
        }
        return adding && player.isQueueEmpty(modelContext)
    }

    func scrollToChapterIfNeeded(hasChapters: Bool, proxy: ScrollViewProxy) {
        guard hasChapters && player.video?.youtubeId == video.youtubeId else {
            return
        }
        if scrollToCurrent {
        } else if navManager.scrollToCurrentChapter {
            navManager.scrollToCurrentChapter = false
        } else {
            return
        }
        var chapter = player.currentChapter
        var anchor: UnitPoint = .center

        // one row of context above the current chapter, taken from the list's own order
        let listed = video.orderedChapterData
        if let current = player.currentChapter,
           let index = listed.firstIndex(where: { $0.chapterId == current.chapterId }),
           index > 0 {
            chapter = listed[index - 1]
            anchor = .top
        }
        proxy.scrollTo(
            chapter?.chapterId,
            anchor: anchor
        )
    }

    func onTitleTap() {
        if let url = video.url?.absoluteString {
            navManager.openUrlInApp(.url(url))
            navManager.videoDetail = nil
        }
    }

    func handleDone() {
        undoManager.registerAction(.moveToInbox([video.persistentModelID]))
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
            navManager.videoDetail = nextVideo
        } else if let firstEntry = entries.first, let firstVideo = firstEntry.video {
            navManager.videoDetail = firstVideo
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
        playerControlBackground(in: .circle)
        #endif
    }
}

private struct FixedToolbarSpacer: ToolbarContent {
    let placement: ToolbarItemPlacement

    var body: some ToolbarContent {
        #if os(visionOS)
        ToolbarItem(placement: placement) { EmptyView() }
        #else
        ToolbarSpacer(.fixed, placement: placement)
        #endif
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                ChapterDescriptionView(video: DataProvider.dummyVideo)
                    .previewEnvironments()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            DismissSheetButton()
                        }
                    }
            }
        }
}
