//
//  LibraryNavListItem.swift
//  Unwatched
//

import SwiftUI

struct LibraryNavListItem: View {
    var text: LocalizedStringKey
    var systemName: String

    init(_ text: LocalizedStringKey, systemName: String) {
        self.text = text
        self.systemName = systemName
    }

    var body: some View {
        Label {
            Text(text)
                .foregroundStyle(Color.neutralAccentColor)
        } icon: {
            Image(systemName: systemName)
        }
    }
}

#Preview {
    LibraryNavListItem("library", systemName: "star")
}
