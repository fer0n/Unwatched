//
//  AutoRemoveNewViewModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AutoRemoveNewViewModifier: ViewModifier {
    @AppStorage(Const.autoClearNew) var autoClearNew: Bool = false
    @Environment(NavigationManager.self) var navManager

    var hasNewItems: Bool
    var list: NavigationTab

    func body(content: Content) -> some View {
        content
            .onChange(of: navManager.tab) { oldTab, newTab in
                if autoClearNew && hasNewItems && (oldTab == list || newTab == list) {
                    VideoService.clearNewStatus(for: list)
                }
            }
    }
}

extension View {
    func autRemoveNewViewModifier(
        hasNewItems: Bool,
        list: NavigationTab
    ) -> some View {
        self.modifier(AutoRemoveNewViewModifier(hasNewItems: hasNewItems, list: list))
    }
}
