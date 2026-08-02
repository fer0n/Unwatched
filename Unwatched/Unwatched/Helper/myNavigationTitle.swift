//
//  CustomNavigationTitle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MyNavigationTitle: ViewModifier {
    var title: LocalizedStringKey?
    var titleHidden = false
    /// Fades the title on its own, e.g. while a gesture drags something towards it. A closure, so
    /// an observable it reads invalidates only the title rather than the whole screen.
    var titleOpacity: () -> Double = { 1 }
    /// Appended after the title, e.g. an inbox count, and faded along with it
    var titleAccessory: Text?

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                if let title {
                    ToolbarItem(placement: .principal) {
                        TitleLabel(text: titleText(title), hidden: titleHidden, opacity: titleOpacity)
                    }
                }
            }
        #else
        .navigationTitle(title ?? "")
        .updateNavTitle(title, titleHidden: titleHidden)
        #endif
    }

    private func titleText(_ title: LocalizedStringKey) -> Text {
        let text = Text(title).fontWeight(.black)
        guard let titleAccessory else { return text }
        return text + Text(" ") + titleAccessory
    }
}

/// Its own view, so a changing `opacity` doesn't invalidate the toolbar around it
private struct TitleLabel: View {
    let text: Text
    let hidden: Bool
    let opacity: () -> Double

    var body: some View {
        text
            .offset(y: hidden ? 10 : 0)
            .opacity(hidden ? 0 : opacity())
            .blur(radius: hidden ? 3 : 0)
            .lineLimit(1)
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
                titleAccessory: titleAccessory
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
