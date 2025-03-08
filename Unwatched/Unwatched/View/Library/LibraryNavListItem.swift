//
//  LibraryNavListItem.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct LibraryNavListItem: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    var text: LocalizedStringKey
    var systemName: String?
    var imageName: String?

    init(_ text: LocalizedStringKey, systemName: String) {
        self.text = text
        self.systemName = systemName
    }

    init(_ text: LocalizedStringKey, imageName: String) {
        self.text = text
        self.imageName = imageName
    }

    var body: some View {
        Label {
            Text(text)
                .foregroundStyle(Color.neutralAccentColor)
        } icon: {
            if let systemName = systemName {
                Image(systemName: systemName)
            } else if let imageName = imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(1)
            }
        }
        .foregroundStyle(theme.color)
    }
}

#Preview {
    LibraryNavListItem("library", systemName: "star")
}
