//
//  DismissToolbarButton.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared

struct DismissToolbarButton: ToolbarContent {
    @Environment(\.dismiss) var dismiss

    var action: (() -> Void)?

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                if let action = action {
                    action()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: Const.clearNoFillSF)
            }
            .fontWeight(.bold)
            .accessibilityLabel("dismiss")
            .myTint(neutral: true)
            .foregroundStyle(Color.neutralAccentColor)
        }
    }
}
