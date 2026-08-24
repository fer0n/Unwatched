//
//  TranscriptDescriptionSelection.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TranscriptDescriptionSelection: View {
    @Environment(PlayerManager.self) var player

    let video: Video
    let isCurrentVideo: Bool
    let scrollProxy: ScrollViewProxy
    @Binding var transcriptVM: TranscriptView.ViewModel

    @State var selection: DescriptionContentType = .description

    var body: some View {
        if !hasTranscript {
            DescriptionDetailView(description: video.videoDescription)
        } else {
            selection(for: video)
        }
    }

    var hasTranscript: Bool {
        Self.canHaveTranscript(video, isCurrentVideo: isCurrentVideo, transcriptUrl: player.transcriptUrl)
    }

    /// A video the player has already reported as having no captions never gets any either, so the tab and the
    /// chapter tools built on a transcript aren't worth offering for it.
    static func canHaveTranscript(_ video: Video, isCurrentVideo: Bool, transcriptUrl: String?) -> Bool {
        if video.isPodcast {
            return true
        }
        return !(isCurrentVideo && transcriptUrl == "")
    }

    @ViewBuilder
    func selection(for video: Video) -> some View {
        CapsuleSegmentedControl(
            selection: $selection,
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
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 8)
        .onChange(of: selection) {
            if selection == .transcript {
                Signal.log("Transcript.View")
            }
        }

        if selection == .description {
            DescriptionDetailView(description: video.videoDescription)
        } else {
            TranscriptView(
                video: video,
                transcriptUrl: isCurrentVideo ? player.transcriptUrl : nil,
                youtubeId: video.youtubeId,
                viewModel: $transcriptVM,
                scrollProxy: scrollProxy
            )
            .padding(.bottom, 7)
        }
    }
}

enum DescriptionContentType {
    case description
    case transcript
}
