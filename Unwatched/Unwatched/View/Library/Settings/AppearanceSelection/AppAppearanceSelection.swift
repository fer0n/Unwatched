//
//  AppAppearanceSelection.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AppAppearanceSelection: View {
    @Environment(\.colorScheme) var colorScheme

    @Binding var selection: AppAppearance
    @State var width: CGFloat = 100

    var body: some View {
        let spacing: CGFloat = width / 10

        ZStack {
            Color.insetBackgroundColor
                .scaleEffect(2)

            HStack(spacing: spacing) {
                ForEach(AppAppearance.allCases, id: \.self) { appearance in
                    UnwatchedMiniature(
                        appearance,
                        width: (width / 3) - spacing,
                        selected: selection == appearance
                    )
                    .onTapGesture {
                        selection = appearance
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .onSizeChange { size in
                width = size.width
            }
        }
    }
}

#Preview {
    AppAppearanceSelection(selection: .constant(.unwatched))
}
