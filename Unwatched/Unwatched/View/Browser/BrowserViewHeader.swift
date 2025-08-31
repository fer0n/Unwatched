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
            let bigScreen = sizeClass == .regular
            if bigScreen {
                Label("close", systemImage: "chevron.down")
                    .labelStyle(.titleAndIcon)
                    .padding(10)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            } else {
                Color.secondary
                    .opacity(0.5)
                    .frame(width: 36, height: 5)
                    .clipShape(Capsule())
                    .padding(.top, 5)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityLabel("close")
        .keyboardShortcut(.escape, modifiers: [])
        .foregroundStyle(Color.neutralAccentColor)
    }
}
