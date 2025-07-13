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

    @State var selection: DescriptionContentType = .description
    @State var transcriptVM = TranscriptView.ViewModel()

    var body: some View {
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

        if selection == .description {
            DescriptionDetailView(description: video.videoDescription)
        } else {
            TranscriptView(
                transcriptUrl: isCurrentVideo ? player.transcriptUrl : nil,
                youtubeId: video.youtubeId,
                viewModel: $transcriptVM,
                )
            .padding(.bottom, 7)
        }
    }
}

enum DescriptionContentType {
    case description
    case transcript
}
