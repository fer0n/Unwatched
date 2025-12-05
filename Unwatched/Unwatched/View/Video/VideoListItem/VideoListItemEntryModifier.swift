//
//  VideoListItemEntryModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension View {
    func videoListItemEntry() -> some View {
        self
            #if os(iOS) || os(visionOS)
            .listRowInsets(.init(
                top: 0,
                leading: 5,
                bottom: 0,
                trailing: 5
            ))
            .padding(5)
            #else
            .listRowInsets(.init(
            top: 0,
            leading: 0,
            bottom: 0,
            trailing: 0
            ))
            #endif
            .listRowSeparator(.hidden)
            .contentShape(
                kinds,
                RoundedRectangle(cornerRadius: Const.videoCornerRadius + 5)
            )
            #if os(visionOS)
            .hoverEffect()
        #endif
    }

    private var kinds: ContentShapeKinds {
        #if os(visionOS)
        [.dragPreview, .hoverEffect]
        #else
        .dragPreview
        #endif
    }
}
