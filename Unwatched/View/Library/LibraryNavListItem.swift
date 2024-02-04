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
        HStack {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
                .foregroundStyle(.white, color)
                .padding([.vertical, .trailing], 6)
            Text(text)
        }
    }
}

#Preview {
    LibraryNavListItem("star", systemName: "star")
}
