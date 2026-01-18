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

    let video: Video
    var bottomSpacer: CGFloat = 0
    var isCompact = false
    var scrollToCurrent = false
    var isTransparent = false
    var showThumbnail = true
    var showActions = true

    var body: some View {
        let hasChapters = video.sortedChapters.isEmpty == false

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

                    ChapterSettingsMenu(video: player.video)

                    Spacer()
                        .frame(height: 10)

                    TranscriptDescriptionSelection(
                        video: video,
                        isCurrentVideo: video.youtubeId == player.video?.youtubeId,
                        )
                }
                .padding(.horizontal, showThumbnail ? 15 : isCompact ? 10 : 20)
                .padding(.top, showThumbnail ? 15 : isCompact ? 15 : 30)
                .frame(idealWidth: 500, maxWidth: 800, alignment: .leading)

                Spacer()
                    .frame(height: bottomSpacer)

                Spacer()
                    .frame(maxWidth: .infinity)
            }
            .onAppear {
                if hasChapters && player.video?.youtubeId == video.youtubeId {
                    if scrollToCurrent {
                    } else if navManager.scrollToCurrentChapter {
                        navManager.scrollToCurrentChapter = false
                    } else {
                        return
                    }
                    var chapter = player.currentChapter
                    var anchor: UnitPoint = .center

                    if let current = player.currentChapter,
                       let index = video.sortedChapters.firstIndex(where: {
                        $0.persistentModelID == current.persistentModelID
                       }),
                       index > 0 {
                        chapter = video.sortedChapters[index - 1]
                        anchor = .top
                    }
                    proxy.scrollTo(
                        chapter?.persistentModelID,
                        anchor: anchor
                    )
                }
            }
            .if(showActions) { view in
                Group {
                    #if os(macOS)
                    view.overlay {
                        actionOverlay
                    }
                    #else
                    if #available(iOS 17.0, visionOS 1.0, *) {
                        view.toolbar {
                            ToolbarItemGroup(placement: Device.isVision ? .topBarTrailing : .bottomBar) {
                                #if os(visionOS)
                                buttons
                                    .buttonBorderShape(.circle)
                                #else
                                buttons
                                #endif
                            }
                        }
                    } else {
                        view.overlay {
                            actionOverlay
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

    @ViewBuilder
    var buttons: some View {
        Button {
            playVideo()
            Signal.log("VideoDetail.Play", throttle: .weekly)
        } label: {
            Image(systemName: "play.fill")
        }

        Button {
            addToQueueNext()
            Signal.log("VideoDetail.QueueNext", throttle: .weekly)
        } label: {
            Image(systemName: Const.queueNextSF)
        }

        Button {
            addToQueueLast()
            Signal.log("VideoDetail.QueueLast", throttle: .weekly)
        } label: {
            Image(systemName: Const.queueLastSF)
        }

        Button {
            clearVideo()
            Signal.log("VideoDetail.Clear", throttle: .weekly)
        } label: {
            #if os(visionOS)
            Text("clear")
            #else
            Image(systemName: Const.clearNoFillSF)
            #endif
        }
        .disabled(!canBeCleared)
        .buttonBorderShape(.automatic)
    }

    @ViewBuilder
    var actionOverlay: some View {
        HStack(spacing: 20) {
            buttons
                .buttonStyle(.plain)
        }
        .padding(15)
        .background(.ultraThinMaterial, in: .capsule)
        .frame(maxHeight: .infinity, alignment: .bottom)
        #if os(macOS)
        .padding()
        #endif
    }

    var canBeCleared: Bool {
        video.inboxEntry != nil || video.queueEntry != nil
    }

    func playVideo() {
        VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
        player.playVideo(video)
        navManager.handlePlay()
    }

    func addToQueueNext() {
        let requiresQueueChange = requiresQueueChange()
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
        let requiresQueueChange = requiresQueueChange()
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

    func requiresQueueChange() -> Bool {
        return video.queueEntry?.order == 0
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
