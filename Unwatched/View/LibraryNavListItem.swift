//
//  LibraryNavListItem.swift
//  Unwatched
//

import SwiftUI

struct LibraryNavListItem: View {
    var text: LocalizedStringKey
    var systemName: String
    var color: Color? = .blue

    init(_ text: LocalizedStringKey, systemName: String, _ color: Color? = nil) {
        self.text = text
        self.systemName = systemName
        self.color = color
    }

    var body: some View {
        HStack {
            Image(systemName: systemName)
                .resizable()
                .frame(width: 23, height: 23)
                .foregroundColor(color)
                .padding([.vertical, .trailing], 6)
            Text(text)
        }
    }
}

// #Preview {
//    LibraryNavListItem()
// }
