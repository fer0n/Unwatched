//
//  CustomNavigationTitle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MyNavigationTitle: ViewModifier {
    var title: LocalizedStringKey?
    var titleHidden = false

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                if let title {
                    ToolbarItem(placement: .principal) {
                        VStack {
                            Text(title)
                                .fontWeight(.black)
                                .offset(y: titleHidden ? 10 : 0)
                                .opacity(titleHidden ? 0 : 1)
                                .blur(radius: titleHidden ? 3 : 0)
                                .lineLimit(1)
                        }
                    }
                }
            }
        #else
        .navigationTitle(title ?? "")
        .updateNavTitle(title, titleHidden: titleHidden)
        #endif
    }
}

extension View {
    func myNavigationTitle(_ title: LocalizedStringKey? = nil, titleHidden: Bool = false
    ) -> some View {
        self.modifier(
            MyNavigationTitle(
                title: title,
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
