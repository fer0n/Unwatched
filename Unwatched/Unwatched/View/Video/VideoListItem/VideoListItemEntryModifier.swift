//
//  VideoListItemEntryModifier.swift
//  Unwatched
//

import SwiftUI

struct VideoListItemEntryModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowSeparator(.hidden)
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 15))
            #if os(iOS)
            .padding(.vertical, -2)
        #else
        .padding(3)
        #endif
    }
}

extension View {
    func videoListItemEntry() -> some View {
        self.modifier(VideoListItemEntryModifier())
    }
}
