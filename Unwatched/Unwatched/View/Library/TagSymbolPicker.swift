//
//  TagSymbolPicker.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TagSymbolPicker: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @Binding var symbol: String?

    /// What the tag falls back to, so no symbol reads as the one the mode already shows.
    let defaultSymbol: String

    private let columns = [GridItem(.adaptive(minimum: 54), spacing: 10)]

    var body: some View {
        let selectedSymbol = symbol ?? defaultSymbol

        ZStack {
            MyBackgroundColor()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(TagSymbolPicker.groups, id: \.id) { group in
                        Section {
                            ForEach(group.symbols, id: \.self) { name in
                                let isSelected = name == selectedSymbol
                                SymbolCell(
                                    name: name,
                                    foreground: isSelected ? theme.contrastColor : Color.neutralAccentColor,
                                    background: isSelected ? theme.color : Color.insetBackgroundColor
                                )
                                .onTapGesture { symbol = name }
                                .accessibilityAction { symbol = name }
                            }
                        } header: {
                            Text(group.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 10)
                        }
                    }
                }
                .padding()
            }
        }
        .myTint()
        .myNavigationTitle("symbol")
    }

    /// `TapGesture`, not `Button`: a button fires on a drag that starts and ends on it, which
    /// picked symbols while scrolling. Colors are passed in so a cell holds no `@AppStorage`.
    private struct SymbolCell: View {
        let name: String
        let foreground: Color
        let background: Color

        var body: some View {
            Image(systemName: name)
                .font(.system(size: 22))
                .frame(width: 54, height: 54)
                .foregroundStyle(foreground)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(background)
                }
                .contentShape(.rect(cornerRadius: 12))
                .accessibilityElement()
                .accessibilityLabel(name)
                .accessibilityAddTraits(.isButton)
        }
    }
}

#Preview {
    NavigationStack {
        TagSymbolPicker(symbol: .constant("star.fill"), defaultSymbol: TagMode.include.defaultSymbol)
    }
}
