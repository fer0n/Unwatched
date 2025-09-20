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
                .apply {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        $0
                            .foregroundStyle(.automaticBlack, .clear)
                            .glassEffect(.regular.interactive(), in: Circle())
                    } else {
                        $0
                            .foregroundStyle(.automaticWhite, .automaticBlack)
                    }
                }
                .fontWeight(.black)
        }
        .padding(.trailing, PlayerView.miniPlayerHorizontalPadding)
    }
}
