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
            .contentShape(Rectangle())
            .onTapGesture(perform: handleMiniPlayerTap)
            .lineLimit(2)

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
        .padding(.trailing, PlayerView.miniPlayerHorizontalPadding)
    }
}
