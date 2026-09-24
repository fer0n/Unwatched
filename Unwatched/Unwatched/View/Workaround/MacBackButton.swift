//
//  MacBackButton.swift
//  Unwatched
//

import SwiftUI

#if os(macOS)
struct MacBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .fontWeight(.semibold)
                // the size of the native toolbar buttons next to it
                .frame(width: 36, height: 36)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
    }
}
#endif
