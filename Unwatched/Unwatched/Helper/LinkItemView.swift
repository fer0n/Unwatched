//
//  LinkItemView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct LinkItemView<Content: View>: View {
    let destination: URL
    let label: LocalizedStringKey
    let content: () -> Content

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 20) {
                content()
                    .frame(width: 24, height: 24)
                    .tint(.neutralAccentColor)
                Text(label)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: Const.listItemChevronSF)
                    .tint(.neutralAccentColor)
            }
        }
        .accessibilityLabel(label)
    }
}
