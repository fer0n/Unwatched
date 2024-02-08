//
//  LibraryNavListItem.swift
//  Unwatched
//

import SwiftUI

struct LibraryNavListItem: View {
    var text: LocalizedStringKey
    var systemName: String
    var color: Color

    init(_ text: LocalizedStringKey, systemName: String, _ color: Color? = nil) {
        self.text = text
        self.systemName = systemName
        self.color = color ?? .blue
    }

    var body: some View {
        Label(text, systemImage: systemName)
            .foregroundStyle(.white, color)
    }
}

#Preview {
    LibraryNavListItem("star", systemName: "star", .cyan)
}
