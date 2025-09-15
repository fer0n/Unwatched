//
//  UpdateNavTitle.swift
//  Unwatched
//

import SwiftUI

@available(macOS 26, *)
struct UpdateNavTitle: ViewModifier {
    @Environment(NavigationTitleManager.self) var navigationTitleManager
    var title: LocalizedStringKey?
    var titleHidden: Bool = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                pushTitle()
            }
            .onDisappear {
                popTitleIfNeeded()
            }
            .onChange(of: titleHidden) {
                replaceTitle()
            }
    }

    private func pushTitle() {
        if titleHidden {
            navigationTitleManager.push("")
        } else if let title {
            navigationTitleManager.push(title)
        }
    }

    private func replaceTitle() {
        if titleHidden {
            navigationTitleManager.replaceTop("")
        } else if let title {
            navigationTitleManager.replaceTop(title)
        }
    }

    private func popTitleIfNeeded() {
        navigationTitleManager.pop()
    }
}

extension View {
    func updateNavTitle(_ title: LocalizedStringKey?, titleHidden: Bool = false) -> some View {
        self.apply {
            if #available(macOS 26, *) {
                $0.modifier(UpdateNavTitle(title: title, titleHidden: titleHidden))
            } else {
                $0
            }
        }
    }
}
