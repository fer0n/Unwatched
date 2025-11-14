//
//  LibraryNavListItem.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct LibraryNavListItem: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    var text: LocalizedStringKey
    var subTitle: LocalizedStringKey?
    var systemName: String?
    var imageName: String?

    init(_ text: LocalizedStringKey, subTitle: LocalizedStringKey? = nil, systemName: String) {
        self.text = text
        self.subTitle = subTitle
        self.systemName = systemName
    }

    init(_ text: LocalizedStringKey, subTitle: LocalizedStringKey? = nil, imageName: String) {
        self.text = text
        self.subTitle = subTitle
        self.imageName = imageName
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 0) {
                Text(text)
                    .foregroundStyle(Color.neutralAccentColor)
                if let subTitle {
                    Text(subTitle)
                        .foregroundStyle(Color.neutralAccentColor.opacity(0.5))
                }
            }
        } icon: {
            if let systemName {
                Image(systemName: systemName)
            } else if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(1)
            }
        }
        #if os(visionOS)
        .foregroundStyle(.primary)
        #else
        .foregroundStyle(theme.color)
        #endif
    }
}

#Preview {
    LibraryNavListItem("library", systemName: "star")
}
