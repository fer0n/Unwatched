//
//  TranscriptView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TranscriptView: View {
    @Environment(PlayerManager.self) var player

    let video: Video
    let transcriptUrl: String?
    let youtubeId: String

    @Binding var viewModel: ViewModel
    let scrollProxy: ScrollViewProxy

    @State private var autoScroll = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                searchBar
                driftBanner
                if showsGenerateButton {
                    generateTranscriptButton
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                } else if viewModel.transcript?.isEmpty != false {
                    Text(transcriptStatus)
                        .italic()
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            TranscriptList(
                                transcript: viewModel.filteredTranscript,
                                activeTime: activeTime,
                                isCurrentVideo: isCurrentVideo,
                                isSearching: !viewModel.text.debounced.isEmpty
                            )
                        } header: {
                            followTranscriptButton
                                .padding(.vertical)
                        }
                    }
                    .background {
                        ScrollViewInteractionDetector {
                            autoScroll = false
                        }
                    }
                    .onChange(of: activeEntryId) { _, _ in
                        if autoScroll, let id = scrollTargetId {
                            withAnimation {
                                scrollProxy.scrollTo(id, anchor: .top)
                            }
                        }
                    }
                }

                Spacer()
                    .frame(height: 300)
                    .task(id: refreshId) {
                        await viewModel.handleTranscriptLoading(
                            video,
                            transcriptUrl
                        )
                        await viewModel.checkAlignmentIfCheap(for: video)
                    }
            }
        }
    }

    /// Offered rather than applied: correcting the timings rewrites what the user is reading, and
    /// the check that found the drift is cheap enough to be wrong occasionally.
    var showsDriftBanner: Bool {
        viewModel.driftDetected && !viewModel.isAligning
    }

    @ViewBuilder
    var driftBanner: some View {
        if showsDriftBanner {
            Button {
                Signal.log("Transcript.Align", parameters: ["source": "banner"])
                viewModel.alignTranscript(for: video)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.arrow.trianglehead.counterclockwise.rotate.90")
                    Text("transcriptOutOfSync")
                    Spacer()
                    Text("fixTranscriptAlignment")
                        .fontWeight(.semibold)
                }
                .font(.footnote)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.automaticBlack)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            #if os(iOS)
            .background(Capsule().fill(Color.insetBackgroundColor))
            #endif
            .padding(.vertical, 8)
            // opacity only: a moving transition draws the banner over the search field above it
            .transition(.opacity)
        }
    }

    var searchBar: some View {
        HStack {
            TranscriptSearch(text: $viewModel.text)
                .padding(.leading, 10)

            TranscriptFieldClearButton(text: $viewModel.text)
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        #if os(iOS)
        .background(Capsule().fill(Color.insetBackgroundColor))
        #endif
    }

    @ViewBuilder
    var followTranscriptButton: some View {
        if viewModel.transcript?.isEmpty == false && isCurrentVideo {
            Button {
                autoScroll = true
                if let id = scrollTargetId {
                    withAnimation {
                        scrollProxy.scrollTo(id, anchor: .top)
                    }
                }
            } label: {
                Label("scrollToNow", systemImage: "location.fill")
            }
            .buttonBorderShape(.capsule)
            .foregroundStyle(Color.automaticBlack)
            #if !os(visionOS)
            .tint(Color.insetBackgroundColor)
            #endif
            .buttonStyle(.borderedProminent)
            .opacity(autoScroll ? 0 : 1)
            .animation(.default, value: autoScroll)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    var showsGenerateButton: Bool {
        video.isPodcast
            && TranscriptService.canGenerateTranscript
            && !viewModel.isLoading
            && viewModel.transcript?.isEmpty == true
    }

    var generateTranscriptButton: some View {
        Button {
            guard guardPremium() else { return }
            Signal.log("Transcript.Generate", parameters: ["source": "emptyTranscript"])
            viewModel.generateTranscript(for: video)
        } label: {
            Label("generateTranscript", systemImage: "text.quote")
        }
        .buttonBorderShape(.capsule)
        .foregroundStyle(Color.automaticBlack)
        #if !os(visionOS)
        .tint(Color.insetBackgroundColor)
        #endif
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isGenerating)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var transcriptStatus: LocalizedStringKey {
        if viewModel.isLoading {
            return "loadingTranscript"
        }
        if video.isPodcast {
            return "noTranscriptYet"
        }
        if isCurrentVideo {
            if player.transcriptUrl == "" {
                return "transcriptUnavailable"
            }
        }
        if viewModel.transcript == nil {
            return "startToLoadTranscript"
        }
        // empty transcript means unavailable
        return "transcriptUnavailable"
    }

    var activeTime: Double {
        (player.currentTime ?? 0) + 1
    }

    var activeEntryId: UUID? {
        guard isCurrentVideo, let transcript = viewModel.transcript else { return nil }
        let time = activeTime
        return transcript.first(where: {
            $0.start < time && ($0.start + $0.duration) >= time
        })?.id
    }

    var scrollTargetId: UUID? {
        guard isCurrentVideo, let transcript = viewModel.transcript else { return nil }
        let time = activeTime
        guard let activeIndex = transcript.firstIndex(where: {
            $0.start < time && ($0.start + $0.duration) >= time
        }) else { return nil }

        let targetIndex = max(0, activeIndex - 3)
        return transcript[targetIndex].id
    }

    var refreshId: String {
        youtubeId + (transcriptUrl ?? "empty")
    }

    var isCurrentVideo: Bool {
        player.video?.youtubeId == youtubeId
    }
}
