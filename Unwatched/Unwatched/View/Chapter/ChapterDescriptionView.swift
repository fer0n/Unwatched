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
    @Environment(TinyUndoManager.self) var undoManager
    @Environment(AppNotificationVM.self) var appNotificationVM

    @State var hapticToggle = false
    @State var transcriptVM = TranscriptView.ViewModel()
    @State var descriptionSelection: DescriptionContentType = .description

    private static let pageTopId = "chapterDescriptionPageTop"
    #if os(macOS)
    @ScaledMetric var buttonSize: CGFloat = 46
    #endif

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
                        VideoDetailThumbnail(video: video, onTap: playVideo) {
                            if showActions {
                                playButton
                            }
                        }
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
                        chapterControlsRow(showSegmentedControl: hasTranscript)
                            .padding(.top)

                        Spacer()
                            .frame(height: 10)
                    }

                    TranscriptDescriptionSelection(
                        video: video,
                        isCurrentVideo: isCurrentVideo,
                        scrollProxy: proxy,
                        transcriptVM: $transcriptVM,
                        selection: $descriptionSelection
                    )
                    .transition(.opacity)
                }
                .padding(.horizontal, showThumbnail ? 15 : isCompact ? 10 : 20)
                .padding(.top, showThumbnail ? 15 : isCompact ? 15 : 30)
                .frame(idealWidth: 500, maxWidth: 800, alignment: .leading)
                .id(Self.pageTopId)

                Spacer()
                    .frame(height: bottomSpacer)

                Spacer()
                    .frame(maxWidth: .infinity)
            }
            .task(id: video.youtubeId) {
                transcriptVM.syncGeneration(for: video.youtubeId)
                // loaded eagerly rather than when the transcript tab is opened: the settings menu offers
                // generating and restoring on what's there, so it has to know before the tab is touched
                guard video.isPodcast, TranscriptService.canGenerateTranscript else { return }
                await transcriptVM.handleTranscriptLoading(video, nil)
                // kept running for the lifetime of this screen so a generation started elsewhere — a Shortcut,
                // say — still shows its progress here and loads the result once it lands
                await transcriptVM.watchGeneration(for: video)
            }
            // not on the generate button: the menu can start a generation or a restore after it's gone
            .task(id: transcriptVM.generationError) {
                if let error = transcriptVM.generationError {
                    appNotificationVM.show(error, isError: true)
                }
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
                    view.safeAreaInset(edge: .bottom) {
                        actionBar
                    }
                    #else
                    view.toolbar {
                        actionToolbar
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

    /// The description/transcript segmented control with the chapter settings menu kept as its own
    /// control right next to it — the pair centered together, or just the button on its own once
    /// there's no segmented control to show.
    @ViewBuilder
    func chapterControlsRow(showSegmentedControl: Bool) -> some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)
            if showSegmentedControl {
                CapsuleSegmentedControl(
                    selection: $descriptionSelection,
                    items: [
                        CapsuleSegmentItem(
                            title: "description",
                            value: DescriptionContentType.description
                        ),
                        CapsuleSegmentItem(
                            title: "transcript",
                            value: DescriptionContentType.transcript
                        )
                    ]
                )
                .frame(maxWidth: 260)
                ChapterSettingsMenu(video: video, transcriptVM: transcriptVM, iconOnly: true)
            } else {
                ChapterSettingsMenu(video: video, transcriptVM: transcriptVM)
            }
            Spacer(minLength: 0)
        }
        .onChange(of: descriptionSelection) {
            if descriptionSelection == .transcript {
                Signal.interaction("Transcript.View")
            }
        }
    }

    var isCurrentVideo: Bool {
        video.youtubeId == player.video?.youtubeId
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
        // one row of context above; the first chapter scrolls to the top, as centering it overshoots for a frame
        let listed = video.orderedChapterData
        if let current = player.currentChapter,
           let index = listed.firstIndex(where: { $0.chapterId == current.chapterId }) {
            proxy.scrollTo(index > 0 ? listed[index - 1].chapterId : Self.pageTopId, anchor: .top)
        } else {
            proxy.scrollTo(player.currentChapter?.chapterId, anchor: .center)
        }
    }

    func onTitleTap() {
        if let url = video.url?.absoluteString {
            navManager.openUrlInApp(.url(url))
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
