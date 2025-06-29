//
//  SubscriptionTitleFilterButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionTitleFilterButton: View {
    @Binding var showFilter: Bool
    var hasFilter: Bool

    var body: some View {
        Button {
            showFilter.toggle()
        } label: {
            CapsuleMenuLabel(
                systemImage: "line.3.horizontal.decrease",
                menuLabel: "filterSettings",
                text: text
            )
        }
        .buttonStyle(CapsuleButtonStyle(primary: showFilter))
    }

    var text: String {
        hasFilter ? String(localized: "active") : String(localized: "inactive")
    }
}
