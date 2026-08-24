//
//  MiniPlayerContent.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MiniPlayerContent: View {
    @Environment(PlayerManager.self) var player

    var videoTitle: String?
    var handleMiniPlayerTap: () -> Void

    @State private var hapticToggle = false

    var body: some View {
        Text(verbatim: videoTitle ?? "")
            .frame(maxWidth: .infinity, alignment: .leading)
            .fontWeight(.medium)
            .fontWidth(.condensed)
            .contentShape(Rectangle())
            .onTapGesture(perform: handleMiniPlayerTap)
            .lineLimit(2)

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
                .glassEffect(.regular.interactive(), in: Circle())
                #endif
                .fontWeight(.black)
        }

        seekButton(forward: true)
            .padding(.trailing, PlayerView.miniPlayerHorizontalPadding)
    }

    /// Skipping an ad or a sponsor is the one thing the mini player is used for while it's collapsed, and reaching it
    /// used to mean opening the player first.
    private func seekButton(forward: Bool) -> some View {
        Button {
            _ = forward ? player.seekForward() : player.seekBackward()
            hapticToggle.toggle()
        } label: {
            Image(systemName: seekSymbol(forward: forward))
                .font(.system(size: 16))
                .fontWeight(.medium)
                .frame(width: 34, height: 34)
                #if os(visionOS)
                .foregroundStyle(.automaticWhite)
                .background(Circle().fill(Color.automaticBlack))
                #else
                .foregroundStyle(.automaticBlack)
                .glassEffect(.regular.interactive(), in: Circle())
                #endif
                .frame(width: 38, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            forward
                ? String(localized: "seekForward\(Int(player.userSeekSeconds))")
                : String(localized: "seekBackward\(Int(player.userSeekSeconds))")
        )
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }

    /// The numbered symbols only exist for a handful of values; any other seek length falls back to the plain arrow
    /// rather than to a number that isn't the one being seeked.
    private func seekSymbol(forward: Bool) -> String {
        let base = forward ? "goforward" : "gobackward"
        let seconds = Int(player.userSeekSeconds)
        let available: Set<Int> = [5, 10, 15, 30, 45, 60, 75, 90]
        return available.contains(seconds) ? "\(base).\(seconds)" : base
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
