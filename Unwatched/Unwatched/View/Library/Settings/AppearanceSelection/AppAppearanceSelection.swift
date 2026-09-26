//
//  AppAppearanceSelection.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AppAppearanceSelection: View {

    @Binding var selection: AppAppearance
    @State var width: CGFloat = 100
    @Environment(\.colorScheme) var colorScheme

    var sectionBackgroundColor: Color {
        #if os(macOS)
        colorScheme == .dark ? .black : Color.insetBackgroundColor
        #else
        Color.insetBackgroundColor
        #endif
    }

    var body: some View {
        let spacing: CGFloat = width / 10
        let isWide = !Device.isIphone

        ZStack {
            sectionBackgroundColor
                .scaleEffect(2)

            HStack(spacing: 0) {
                ForEach(AppAppearance.allCases, id: \.self) { appearance in
                    Group {
                        if isWide {
                            UnwatchedMiniatureWide(
                                appearance,
                                width: (width / 2) - spacing,
                                selected: selection == appearance
                            )
                        } else {
                            UnwatchedMiniature(
                                appearance,
                                width: (width / 3) - spacing,
                                selected: selection == appearance
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        selection = appearance
                    }
                }
            }
            .padding(.horizontal, spacing)
            .frame(maxWidth: .infinity)
            .onSizeChange { size in
                width = size.width
            }
        }
        #if os(macOS)
        .frame(maxWidth: 340)
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        #endif
    }
}

#Preview {
    AppAppearanceSelection(selection: .constant(.unwatched))
}
