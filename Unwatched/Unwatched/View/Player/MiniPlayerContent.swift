//
//  MiniPlayerContent.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MiniPlayerContent: View {
    var videoTitle: String?
    var channelTitle: String?
    var handleMiniPlayerTap: () -> Void

    var body: some View {
        titles
            .fontWidth(.condensed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: handleMiniPlayerTap)
            .padding(.trailing, showsButtons ? 0 : PlayerView.miniPlayerHorizontalPadding)

        if showsButtons {
            buttons
        }
    }

    @ViewBuilder
    private var titles: some View {
        let title = Text(verbatim: videoTitle ?? "")
            .fontWeight(.medium)
        let titleOnly = title.lineLimit(2)

        if let channelTitle, !channelTitle.isEmpty {
            ViewThatFits(in: .horizontal) {
                VStack(alignment: .leading, spacing: 1) {
                    title
                        .lineLimit(1)
                        // a title that has to wrap falls through to `titleOnly`
                        .fixedSize(horizontal: true, vertical: false)
                    Text(verbatim: channelTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                titleOnly
            }
        } else {
            titleOnly
        }
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

    private var showsButtons: Bool {
        #if os(iOS)
        !MenuTabBarController.usesProminentPlayButton
        #else
        true
        #endif
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
            channelTitle: "Channel",
            handleMiniPlayerTap: { }
        )
    }
    .frame(height: Const.playerAboveSheetHeight)
    .padding(.horizontal)
    .modelContainer(DataProvider.previewContainer)
    .environment(PlayerManager())
}
