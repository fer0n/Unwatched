//
//  VideoListItemEntryModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoListItemEntryModifier: ViewModifier {
    let padding: CGFloat = 12

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .padding(.vertical, -2)
            #endif
            .padding(padding)
            .listRowSeparator(.hidden)
            .contentShape(
                .dragPreview,
                RoundedRectangle(cornerRadius: Const.videoCornerRadius + padding)
            )
            .padding(-padding)
            #if os(macOS)
            .padding(3)
        #endif
    }
}

extension View {
    func videoListItemEntry() -> some View {
        self.modifier(VideoListItemEntryModifier())
    }
}
