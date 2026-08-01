//
//  UpdateNavToolbar.swift
//  Unwatched
//

import SwiftUI

struct ShowStatsItem: View {
    var body: some View {
        NavigationLink(value: LibraryDestination.stats) {
            Image(systemName: "chart.bar.fill")
        }
        .requiresPremium()
    }
}
