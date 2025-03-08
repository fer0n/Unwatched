//
//  MySection.swift
//  Unwatched
//

import SwiftUI

struct MySection<Content: View>: View {
    let content: Content
    var title: LocalizedStringKey = ""
    var footer: LocalizedStringKey?
    var hasPadding = true

    // For content with a ViewBuilder
    init(hasPadding: Bool = true, @ViewBuilder content: () -> Content) {
        self.hasPadding = hasPadding
        self.content = content()
    }

    // For content with a String
    init(_ title: LocalizedStringKey, hasPadding: Bool = true, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.hasPadding = hasPadding
        self.title = title
    }

    init(_ title: LocalizedStringKey = "",
         footer: LocalizedStringKey?,
         hasPadding: Bool = true,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.hasPadding = hasPadding
        self.content = content()
    }

    var body: some View {
        #if os(iOS)
        iosSection
        #else
        macosSection
        #endif
    }

    @ViewBuilder
    var iosSection: some View {
        if let footer = footer {
            Section {
                content
            } header: {
                Text(title)
                    .fontWeight(.semibold)
            } footer: {
                Text(footer)
            }
            .listRowBackground(Color.insetBackgroundColor)
        } else {
            Section {
                content
            } header: {
                Text(title)
                    .fontWeight(.semibold)
            }
            .listRowBackground(Color.insetBackgroundColor)
        }
    }

    @ViewBuilder
    var macosSection: some View {
        let hasTitle = !(title.stringKey?.isEmpty ?? true)
        if let footer = footer {
            if hasTitle {
                Section {
                    content
                } header: {
                    Text(title)
                        .fontWeight(.semibold)
                        .padding(.top, hasPadding ? 8 : 0)
                } footer: {
                    Text(footer)
                }
            } else {
                Section {
                    content
                } footer: {
                    Text(footer)
                }
            }
        } else {
            if hasTitle {
                Section {
                    content
                } header: {
                    Text(title)
                        .fontWeight(.semibold)
                        .padding(.top, hasPadding ? 8 : 0)
                }
            } else {
                Section {
                    content
                }
            }
        }
    }
}
