//
//  DismissToolbarButton.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct DismissToolbarButton: ToolbarContent {
    @Environment(\.dismiss) var dismiss

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Image(systemName: Const.clearSF)
            }
            .fontWeight(.bold)
        }
    }
}
