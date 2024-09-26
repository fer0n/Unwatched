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

    func body(content: Content) -> some View {
        content
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
                        }
                    }
                }
            }
            .toolbarRole(showBack ? .editor : .automatic)
    }
}

extension View {
    func myNavigationTitle(_ title: LocalizedStringKey? = nil,
                           opaque: Bool = false,
                           showBack: Bool = true) -> some View {
        self.modifier(MyNavigationTitle(title: title, opaque: opaque, showBack: showBack))
    }
}
