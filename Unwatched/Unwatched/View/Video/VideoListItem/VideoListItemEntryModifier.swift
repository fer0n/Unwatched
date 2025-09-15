//
//  VideoListItemEntryModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension View {
    func videoListItemEntry() -> some View {
        self
            #if os(iOS)
            .listRowInsets(.init(
                top: 5,
                leading: 10,
                bottom: 5,
                trailing: 10
            ))
            .padding(5)
            #else
            .listRowInsets(.init(
            top: 5,
            leading: 5,
            bottom: 5,
            trailing: 5
            ))
            #endif
            .listRowSeparator(.hidden)
            .contentShape(
                .dragPreview,
                RoundedRectangle(cornerRadius: Const.videoCornerRadius + 5)
            )
    }
}
