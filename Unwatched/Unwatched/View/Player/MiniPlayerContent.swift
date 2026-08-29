//
//  MiniPlayerContent.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MiniPlayerContent: View {
    var videoTitle: String?
    var handleMiniPlayerTap: () -> Void

    var body: some View {
        Text(verbatim: videoTitle ?? "")
            .frame(maxWidth: .infinity, alignment: .leading)
            .fontWeight(.medium)
            .fontWidth(.condensed)
            .contentShape(Rectangle())
            .onTapGesture(perform: handleMiniPlayerTap)
            .lineLimit(2)

        buttons
    }

    @ViewBuilder
    private var buttons: some View {
        let stack = HStack {
            seekButton(forward: false)

            CorePlayButton(
                circleVariant: true,
                enableHaptics: true,
                enableHelperPopup: false,
                ) { image in
                image
                    .resizable()
                    .frame(width: 45, height: 45)
                    .symbolRenderingMode(.palette)
                    #if os(visionOS)
                    .foregroundStyle(.automaticWhite, .automaticBlack)
                    #else
                    .foregroundStyle(.automaticBlack, .clear)
                    .playerControlBackground(in: Circle())
                    #endif
                    .fontWeight(.black)
            }

            seekButton(forward: true)
        }

        stack
            .padding(.trailing, PlayerView.miniPlayerHorizontalPadding)
    }

    /// Skipping an ad or a sponsor is the one thing the mini player is used for while it's collapsed, and reaching it
    /// used to mean opening the player first.
    private func seekButton(forward: Bool) -> some View {
        CoreSeekButton(forward: forward) { image in
            image
                .font(.system(size: 16))
                .fontWeight(.medium)
                .frame(width: 34, height: 34)
                #if os(visionOS)
                .foregroundStyle(.automaticWhite)
                .background(Circle().fill(Color.automaticBlack))
                #else
                .foregroundStyle(.automaticBlack)
                .playerControlBackground(in: Circle())
                #endif
                .frame(width: 38, height: 44)
                .contentShape(Rectangle())
        }
    }
}

#Preview {
    HStack {
        MiniPlayerContent(
            videoTitle: "A Fairly Long Podcast Episode Title for Testing",
            handleMiniPlayerTap: { }
        )
    }
    .frame(height: Const.playerAboveSheetHeight)
    .padding(.horizontal)
    .modelContainer(DataProvider.previewContainer)
    .environment(PlayerManager())
}
