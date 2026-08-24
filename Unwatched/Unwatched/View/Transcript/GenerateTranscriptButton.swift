//
//  GenerateTranscriptButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Stands in for the chapter button and description/transcript picker on an episode that has neither: a tap
/// transcribes it on device, filling the button's own background left to right as it goes.
struct GenerateTranscriptButton: View {
    @Environment(AppNotificationVM.self) var appNotificationVM

    let video: Video
    @Binding var viewModel: TranscriptView.ViewModel

    var body: some View {
        Button {
            guard guardPremium() else { return }
            Signal.log("Transcript.Generate")
            viewModel.generateTranscript(for: video)
        } label: {
            Label {
                Text("generateTranscript")
            } icon: {
                Image(systemName: viewModel.isGenerating
                        ? "progress.indicator"
                        : "text.quote")
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(
                        .variableColor.iterative.hideInactiveLayers.nonReversing,
                        options: .repeat(.continuous),
                        isActive: viewModel.isGenerating
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.automaticBlack)
        .background(progressFill)
        .clipShape(Capsule())
        .disabled(viewModel.isGenerating)
        .frame(maxWidth: .infinity, alignment: .center)
        .task(id: viewModel.generationError) {
            if let error = viewModel.generationError {
                appNotificationVM.show(error, isError: true)
            }
        }
    }

    /// The base tint with a noticeably lighter sweep grown to `generationProgress`, anchored left.
    var progressFill: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.insetBackgroundColor
                Color.insetBackgroundColor
                    .mix(with: .white, by: 0.25)
                    .frame(width: geo.size.width * viewModel.generationProgress)
            }
        }
        .animation(.linear(duration: 0.3), value: viewModel.generationProgress)
    }
}

#Preview {
    GenerateTranscriptButton(video: DataProvider.dummyVideo, viewModel: .constant(TranscriptView.ViewModel()))
        .appNotificationOverlay()
}
