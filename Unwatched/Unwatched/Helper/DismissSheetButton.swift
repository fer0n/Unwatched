//
//  DismissSheetButton.swift
//  Unwatched
//

import SwiftUI

struct DismissSheetButton: View {
    @Environment(\.dismiss) var dismiss

    var action: (() -> Void)?

    var body: some View {
        Button("cancel", systemImage: "xmark") {
            if let action = action {
                action()
            } else {
                dismiss()
            }
        }
    }
}
