//
//  EmptyEntry.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct EmptyEntry<Entry: PersistentModel>: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme

    let entry: Entry

    init(_ entry: Entry) {
        self.entry = entry
    }

    var body: some View {
        Color.backgroundColor
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    modelContext.delete(entry)
                } label: {
                    Image(systemName: Const.clearSF)
                }
                .tint(theme.color.mix(with: Color.black, by: 0.9))
            }
    }
}
