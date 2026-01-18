//
//  UpdateNavToolbar.swift
//  Unwatched
//

import SwiftUI

struct UpdateStatsToolbarItem: ViewModifier {
    @Environment(NavigationTitleManager.self) var navigationTitleManager
    var value: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                navigationTitleManager.pushShowStatsItem(value)
            }
            .onDisappear {
                navigationTitleManager.popShowStatsItem()
            }
    }
}

extension View {
    func showStatsToolbarItem(_ value: Bool) -> some View {
        self.apply {
            if #available(macOS 26, *) {
                $0.modifier(UpdateStatsToolbarItem(value: value))
            } else {
                $0
            }
        }
    }
}

struct ShowStatsItem: View {
    var body: some View {
        NavigationLink(value: LibraryDestination.stats) {
            Image(systemName: "chart.bar.fill")
        }
        .requiresPremium()
    }
}
