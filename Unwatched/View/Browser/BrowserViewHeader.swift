//
//  BrowserViewHeader.swift
//  Unwatched
//

import SwiftUI

struct BrowserViewHeader: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?

    var body: some View {
        Button {
            dismiss()
        } label: {
            HStack {
                let bigScreen = sizeClass == .regular
                if bigScreen {
                    Label("close", systemImage: "chevron.down")
                        .labelStyle(.titleAndIcon)
                        .padding(10)
                } else {
                    Image(systemName: "chevron.down")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(7)
                }
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel("close")
        .keyboardShortcut(.escape, modifiers: [])
        .foregroundStyle(Color.neutralAccentColor)
    }
}
