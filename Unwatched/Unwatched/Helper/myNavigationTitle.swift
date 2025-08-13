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
    var titleHidden = false

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(toolbarBackground, for: .navigationBar)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                if let title {
                    ToolbarItem(placement: .principal) {
                        VStack {
                            Text(title)
                                .fontWeight(.black)
                                .offset(y: titleHidden ? 10 : 0)
                                .opacity(titleHidden ? 0 : 1)
                                .blur(radius: titleHidden && Const.iOS26 ? 3 : 0)
                                .lineLimit(1)
                        }
                    }
                }
            }
        #else
        .navigationTitle(title ?? "")
        #endif
    }

    var toolbarBackground: Color {
        if #available(iOS 26, *) {
            Color.clear
        } else {
            Color.backgroundColor.opacity(sheetOpacity || opaque ? Const.sheetOpacityValue : 1)
        }
    }
}

extension View {
    func myNavigationTitle(_ title: LocalizedStringKey? = nil,
                           opaque: Bool = false,
                           titleHidden: Bool = false
    ) -> some View {
        self.modifier(
            MyNavigationTitle(
                title: title,
                opaque: opaque,
                titleHidden: titleHidden
            )
        )
    }
}

#Preview {
    NavigationStack {
        Color.backgroundColor
            .myNavigationTitle("Title here")
    }
}
