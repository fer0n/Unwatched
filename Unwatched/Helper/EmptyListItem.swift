//
//  BackgroundPlaceholder.swift
//  Unwatched
//

import SwiftUI

struct EmptyListItem: View {
    var body: some View {
        Color.clear
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
