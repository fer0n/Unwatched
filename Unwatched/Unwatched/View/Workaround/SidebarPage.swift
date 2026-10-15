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
                if headerInContent {
                    Color.clear.frame(height: Self.contentHeaderHeight)
                }
            }
            .overlayPreferenceValue(SidebarPageKey.self) { page in
                GeometryReader { proxy in
                    let fullscreen = navManager.isMacosFullscreen
                    let inContent = headerInContent
                    let height = inContent ? Self.contentHeaderHeight : proxy.safeAreaInsets.top

                    SidebarPageHeader(page: page, showsActions: fullscreen)
                        .padding(.leading, inContent ? 12 : Self.trafficLightsWidth)
                        .padding(.trailing, inContent ? 12 : Self.toolbarItemWidth * CGFloat(page.actions.count + 1))
                        .frame(height: height)
                        .offset(y: inContent ? 0 : -height)
                }
                // fullscreen: measured from the page's top, the inset below is all there is
                .ignoresSafeArea(edges: navManager.isMacosFullscreen ? .top : [])
            }
    }

    /// The header gets its own row instead of sitting in the titlebar strip
    private var headerInContent: Bool {
        navManager.isMacosFullscreen || Self.headerBelowTitlebar
    }

    /// macOS 26's titlebar keeps the clicks meant for a header drawn in it (#227)
    static let headerBelowTitlebar: Bool = {
        if #available(macOS 27, *) {
            return false
        }
        return true
    }()

    static let trafficLightsWidth: CGFloat = 86
    static let toolbarItemWidth: CGFloat = 48
    static let contentHeaderHeight: CGFloat = 52
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
