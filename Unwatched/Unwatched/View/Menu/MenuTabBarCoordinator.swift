//
//  MenuTabBarCoordinator.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import UnwatchedShared

extension MenuTabBarController {
    @MainActor
    final class Coordinator: NSObject, UITabBarControllerDelegate {
        static let playPauseIdentifier = "playPause"

        var navManager: NavigationManager
        var player: PlayerManager
        var onPlayPauseTapped: () -> Void
        let environment = MenuTabEnvironment()
        var scrollProxies = [NavigationTab: ScrollViewProxy]()
        private var appliedLabels: MenuTabLabels?
        private var appliedNeutralTint: Bool?

        init(navManager: NavigationManager, player: PlayerManager, onPlayPauseTapped: @escaping () -> Void) {
            self.navManager = navManager
            self.player = player
            self.onPlayPauseTapped = onPlayPauseTapped
        }

        func tab<Content: View>(_ tab: NavigationTab, @ViewBuilder content: @escaping () -> Content) -> UITab {
            UITab(title: tab.description, image: nil, identifier: tab.rawValue) { _ in
                self.host(tab, content: content)
            }
        }

        func host<Content: View>(_ tab: NavigationTab, @ViewBuilder content: () -> Content) -> UIViewController {
            let hosting = UIHostingController(rootView: MenuTabRoot(tab: tab, coordinator: self, content: content()))
            hosting.view.backgroundColor = .clear
            return hosting
        }

        func updateEnvironment(_ values: EnvironmentValues) {
            if environment.colorScheme != values.colorScheme {
                environment.colorScheme = values.colorScheme
            }
            if environment.dynamicTypeSize != values.dynamicTypeSize {
                environment.dynamicTypeSize = values.dynamicTypeSize
            }
        }

        func select(_ selection: NavigationTab, in controller: UITabBarController) {
            if let tab = uiTab(for: selection, in: controller), controller.selectedTab !== tab {
                controller.selectedTab = tab
            }
        }

        func apply(_ labels: MenuTabLabels, to controller: UITabBarController) {
            guard labels != appliedLabels else { return }
            appliedLabels = labels

            func update(_ tab: UITab?, image: UIImage?, title: String, badge: Bool = false, value: String = "") {
                tab?.image = image
                tab?.title = MenuTabLabel.title(showBadge: badge)
                // VoiceOver reads hidden titles as the symbol name and the badge as "●"
                tab?.viewController?.tabBarItem.accessibilityLabel = title
                tab?.viewController?.tabBarItem.accessibilityValue = value
            }
            func update(_ tab: NavigationTab, symbol: String, badge: Bool = false, value: String = "") {
                let image = Self.symbol(symbol)
                update(uiTab(for: tab, in: controller), image: image, title: tab.description, badge: badge, value: value)
            }

            update(.queue, symbol: labels.queueSymbol, badge: labels.queueBadge, value: labels.queueValue)
            update(.inbox, symbol: labels.inboxSymbol, value: labels.inboxValue)
            update(.library, symbol: "books.vertical")
            update(
                controller.tab(forIdentifier: Self.playPauseIdentifier),
                image: Self.symbol(labels.isPlaying ? "pause" : "play", weight: .black),
                title: labels.isPlaying ? String(localized: "pause") : String(localized: "play")
            )

            let search = uiTab(for: .search, in: controller)
            search?.title = ""
            search?.viewController?.tabBarItem.accessibilityLabel = NavigationTab.search.description
        }

        func applyTint(neutral: Bool, to controller: UITabBarController) {
            guard neutral != appliedNeutralTint else { return }
            appliedNeutralTint = neutral
            controller.tabBar.tintColor = neutral ? UIColor(named: "neutralAccentColor") : nil
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
            if tab.identifier == Self.playPauseIdentifier {
                player.handlePlayButton()
                onPlayPauseTapped()
                Signal.log("Player.PlayPause.Tab", throttle: .daily)
                return false
            }
            if navigationTab(for: tab) == navManager.tab {
                handleTappedTwice(navManager.tab)
            }
            return true
        }

        func tabBarController(
            _ tabBarController: UITabBarController,
            didSelectTab selectedTab: UITab,
            previousTab: UITab?
        ) {
            guard let tab = navigationTab(for: selectedTab), tab != navManager.tab else { return }
            Log.info("handleTabChanged \(tab.rawValue)")
            navManager.tab = tab
            if tab == .search && navManager.searchTabShouldAutoFocus {
                navManager.pendingSearchFocus = true
            }
        }

        private func navigationTab(for tab: UITab) -> NavigationTab? {
            tab is UISearchTab ? .search : NavigationTab(rawValue: tab.identifier)
        }

        private func uiTab(for tab: NavigationTab, in controller: UITabBarController) -> UITab? {
            // UISearchTab doesn't expose a settable identifier, so look it up by type
            tab == .search
                ? controller.tabs.first { $0 is UISearchTab }
                : controller.tab(forIdentifier: tab.rawValue)
        }

        private static func symbol(_ name: String, weight: UIImage.SymbolWeight = .unspecified) -> UIImage? {
            let config = UIImage.SymbolConfiguration(weight: weight)
            return UIImage(systemName: "\(name).fill", withConfiguration: config)
                ?? UIImage(systemName: name, withConfiguration: config)
                ?? UIImage(named: name, in: nil, with: config)
        }

        /// UIKit doesn't pop a hosted `NavigationStack` on a second tap
        private func handleTappedTwice(_ tab: NavigationTab) {
            guard navManager.handleTappedTwice() else {
                withAnimation {
                    navManager.clearNavigationStack(tab)
                }
                return
            }
            if tab == .search {
                navManager.pendingSearchFocus = true
            }
            let proxy = scrollProxies[tab]
            Task { @MainActor in
                withAnimation {
                    proxy?.scrollTo(navManager.topListItemId, anchor: .bottom)
                }
            }
        }
    }
}
#endif
