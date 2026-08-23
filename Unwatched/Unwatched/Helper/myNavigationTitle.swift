//
//  CustomNavigationTitle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MyNavigationTitle<Principal: View>: ViewModifier {
    var title: LocalizedStringKey?
    var titleHidden = false
    /// Fades the title on its own, e.g. while a gesture drags something towards it. A closure, so
    /// an observable it reads invalidates only the title rather than the whole screen.
    var titleOpacity: () -> Double = { 1 }
    /// Appended after the title, e.g. an inbox count, and faded along with it
    var titleAccessory: Text?
    /// Stands in for the title on iOS, so it can double as a control. Only iOS draws the title
    /// itself; elsewhere it belongs to the window and `principal` is dropped.
    @ViewBuilder var principal: (LocalizedStringKey) -> Principal

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                if let title {
                    ToolbarItem(placement: .principal) {
                        principal(title)
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
    func myNavigationTitle(
        _ title: LocalizedStringKey? = nil,
        titleHidden: Bool = false,
        titleOpacity: @escaping () -> Double = { 1 },
        titleAccessory: Text? = nil
    ) -> some View {
        self.modifier(
            MyNavigationTitle(
                title: title,
                titleHidden: titleHidden,
                titleOpacity: titleOpacity,
                titleAccessory: titleAccessory,
                principal: {
                    NavigationTitleLabel(
                        title: $0,
                        accessory: titleAccessory,
                        hidden: titleHidden,
                        opacity: titleOpacity
                    )
                }
            )
        )
    }

    func myNavigationTitle<Principal: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder principal: @escaping () -> Principal
    ) -> some View {
        self.modifier(MyNavigationTitle(title: title, principal: { _ in principal() }))
    }
}

#Preview {
    NavigationStack {
        Color.backgroundColor
            .myNavigationTitle("Title here", titleAccessory: Text("3"))
    }
}
