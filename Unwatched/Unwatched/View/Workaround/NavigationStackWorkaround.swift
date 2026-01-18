//
//  NavigationStackWorkaround.swift
//  Unwatched
//

import SwiftUI

#if os(macOS)
@available(macOS 26, *)
struct NavigationStackWorkaround: ViewModifier {
    @Environment(NavigationTitleManager.self) var navigationTitleManager

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 35)
            content
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
        }
        .toolbar(.hidden, for: .windowToolbar)
        .overlay {
            HStack(alignment: .center, spacing: 10) {
                TrafficLights()
                    .padding(11)
                MacBackButton()
                    .frame(height: 5)
                Text(navigationTitleManager.title ?? "")
                    .font(.headline)
                    .fontWeight(.heavy)
                    .lineLimit(1)
                    .padding(.trailing, 30)

                if navigationTitleManager.showStatsItem {
                    Spacer()
                    ShowStatsItem()
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }
        .ignoresSafeArea(.all)
    }
}

extension View {
    func navigationStackWorkaround() -> some View {
        self.apply {
            if #available(macOS 26, *) {
                $0.modifier(NavigationStackWorkaround())
            } else {
                $0
            }
        }
    }
}
#endif
