//
//  MacBackButton.swift
//  Unwatched
//

import SwiftUI

#if os(macOS)
@available(macOS 26, *)
struct MacBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
#endif
