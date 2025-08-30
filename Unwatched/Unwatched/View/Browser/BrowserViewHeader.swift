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
            #if os(macOS)
            Spacer()
                .frame(height: 20)
            #else
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
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
            }
            #endif
        }
        .accessibilityLabel("close")
        .keyboardShortcut(.escape, modifiers: [])
        .foregroundStyle(Color.neutralAccentColor)
    }
}
