//
//  CustomNavigationTitle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MyNavigationTitle: ViewModifier {
    @AppStorage(Const.sheetOpacity) var sheetOpacity: Bool = false

    var title: LocalizedStringKey?
    var opaque: Bool = false
    var showBack: Bool = true
    var titleHidden = false

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.backgroundColor.opacity(sheetOpacity || opaque ? Const.sheetOpacityValue : 1),
                               for: .navigationBar)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                if let title = title {
                    ToolbarItem(placement: .principal) {
                        VStack {
                            Text(title)
                                .fontWeight(.black)
                                .offset(y: titleHidden ? 10 : 0)
                                .opacity(titleHidden ? 0 : 1)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .toolbarRole(showBack ? .editor : .automatic)
        #else
        .navigationTitle(title ?? "")
        #endif
    }
}

extension View {
    func myNavigationTitle(_ title: LocalizedStringKey? = nil,
                           opaque: Bool = false,
                           showBack: Bool = true,
                           titleHidden: Bool = false
    ) -> some View {
        self.modifier(
            MyNavigationTitle(
                title: title,
                opaque: opaque,
                showBack: showBack,
                titleHidden: titleHidden
            )
        )
    }
}
