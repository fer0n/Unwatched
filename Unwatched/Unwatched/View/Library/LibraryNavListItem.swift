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
    var trailingText: LocalizedStringKey?
    var systemName: String?
    var imageName: String?

    init(
        _ text: LocalizedStringKey,
        subTitle: LocalizedStringKey? = nil,
        trailingText: LocalizedStringKey? = nil,
        systemName: String
    ) {
        self.text = text
        self.subTitle = subTitle
        self.trailingText = trailingText
        self.systemName = systemName
    }

    init(
        _ text: LocalizedStringKey,
        subTitle: LocalizedStringKey? = nil,
        trailingText: LocalizedStringKey? = nil,
        imageName: String
    ) {
        self.text = text
        self.subTitle = subTitle
        self.trailingText = trailingText
        self.imageName = imageName
    }

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 0) {
                    Text(text)
                        .fontWeight(.listRow)
                        .foregroundStyle(Color.neutralAccentColor)
                    if let subTitle {
                        Text(subTitle)
                            .foregroundStyle(Color.neutralAccentColor.opacity(0.5))
                    }
                }
            } icon: {
                Group {
                    if let systemName {
                        Image(systemName: systemName)
                    } else if let imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .padding(1)
                    }
                }
                .fontWeight(.listRow)
                #if os(macOS)
                .frame(width: 20, height: 16)
                #endif
            }
            .foregroundStyle(theme.color)

            if let trailingText {
                Spacer()
                Text(trailingText)
                    .font(.body)
                    .foregroundStyle(Color.neutralAccentColor.opacity(0.5))
            }
        }
    }
}

extension Font.Weight {
    static let listRow: Font.Weight = .semibold
}

#Preview {
    LibraryNavListItem("library", systemName: "star")
}
