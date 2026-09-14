//
//  MenuSection.swift
//  Unwatched
//

import SwiftUI

/// A `Section` that drops an empty header, which would still draw a blank row on macOS.
struct MenuSection<Content: View>: View {
    let title: LocalizedStringKey?
    let content: Content

    init(_ title: LocalizedStringKey?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        if let title {
            Section(title) { content }
        } else {
            Section { content }
        }
    }
}
