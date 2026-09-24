//
//  SidebarPage.swift
//  Unwatched
//

import SwiftUI

#if os(macOS)
// Workaround: macOS 26–27's back button pushes sidebar content off screen; remove once fixed
struct SidebarPage: ViewModifier {
    @Environment(NavigationManager.self) var navManager

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden()
            .safeAreaInset(edge: .top, spacing: 0) {
                if navManager.isMacosFullscreen {
                    Color.clear.frame(height: Self.fullscreenHeaderHeight)
                }
            }
            .overlayPreferenceValue(SidebarPageKey.self) { page in
                GeometryReader { proxy in
                    let fullscreen = navManager.isMacosFullscreen
                    let height = fullscreen ? Self.fullscreenHeaderHeight : proxy.safeAreaInsets.top

                    SidebarPageHeader(page: page, showsActions: fullscreen)
                        .padding(.leading, fullscreen ? 12 : Self.trafficLightsWidth)
                        .padding(.trailing, fullscreen ? 12 : Self.toolbarItemWidth * CGFloat(page.actions.count + 1))
                        .frame(height: height)
                        .offset(y: -height)
                }
            }
    }

    static let trafficLightsWidth: CGFloat = 86
    static let toolbarItemWidth: CGFloat = 48
    static let fullscreenHeaderHeight: CGFloat = 52
}

private struct SidebarPageHeader: View {
    let page: SidebarPageInfo
    let showsActions: Bool

    var body: some View {
        HStack(spacing: 10) {
            MacBackButton()
            if let title = page.title {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(page.titleHidden ? 0 : 1)
                    .animation(.default, value: page.titleHidden)
            }
            Spacer(minLength: 0)
            if showsActions {
                ForEach(page.actions.indices, id: \.self) { page.actions[$0] }
            }
        }
    }
}

struct SidebarPageInfo {
    var title: LocalizedStringKey?
    var titleHidden = false
    var actions: [AnyView] = []
}

struct SidebarPageKey: PreferenceKey {
    static var defaultValue: SidebarPageInfo { SidebarPageInfo() }

    static func reduce(value: inout SidebarPageInfo, nextValue: () -> SidebarPageInfo) {
        let next = nextValue()
        if next.title != nil {
            value.title = next.title
            value.titleHidden = next.titleHidden
        }
        value.actions.append(contentsOf: next.actions)
    }
}

extension View {
    func sidebarPage() -> some View {
        self.modifier(SidebarPage())
    }
}
#endif
