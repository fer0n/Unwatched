//
//  VideoListItemEntryModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension View {
    func videoListItemEntry() -> some View {
        let padding: CGFloat = 12

        return self
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
