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
    }
}

extension View {
    func videoListItemEntry() -> some View {
        self.modifier(VideoListItemEntryModifier())
    }
}
