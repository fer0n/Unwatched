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
    @Binding var selection: DescriptionContentType

    var body: some View {
        if !hasTranscript || selection == .description {
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
}

enum DescriptionContentType {
    case description
    case transcript
}
