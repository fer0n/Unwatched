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

    #if os(macOS)
    static let gap: CGFloat = 20
    #else
    static let gap: CGFloat = 0
    #endif

    var body: some View {
        let gap = Self.gap
        // the gap widens the row instead of shrinking the miniatures
        let spacing: CGFloat = (width - gap) / 10
        let isWide = !Device.isIphone

        ZStack {
            #if !os(macOS)
            Color.insetBackgroundColor
                .scaleEffect(2)
            #endif

            HStack(spacing: gap) {
                ForEach(AppAppearance.allCases, id: \.self) { appearance in
                    Group {
                        if isWide {
                            UnwatchedMiniatureWide(
                                appearance,
                                width: ((width - gap) / 2) - spacing,
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
        .frame(maxWidth: 340 + gap)
        .frame(height: 130)
        .frame(maxWidth: .infinity)
        .background {
            // a grouped Form ignores listRowBackground; this covers the section's own box
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? .black : Color.insetBackgroundColor)
                .padding(-10)
                .allowsHitTesting(false)
        }
        #endif
    }
}

#Preview {
    AppAppearanceSelection(selection: .constant(.unwatched))
}
