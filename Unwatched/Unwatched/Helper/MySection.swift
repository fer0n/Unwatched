//
//  MySection.swift
//  Unwatched
//

import SwiftUI

struct MySection<Content: View>: View {
    let content: Content
    var title: LocalizedStringKey = ""
    var footer: LocalizedStringKey?

    // For content with a ViewBuilder
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // For content with a String
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.title = title
    }

    init(_ title: LocalizedStringKey = "",
         footer: LocalizedStringKey?,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        if let footer = footer {
            Section(header: Text(title).fontWeight(.semibold), footer: Text(footer)) {
                content
            }
            .listRowBackground(Color.insetBackgroundColor)
        } else {
            Section(header: Text(title).fontWeight(.semibold)) {
                content
            }
            .listRowBackground(Color.insetBackgroundColor)
        }
    }
}
