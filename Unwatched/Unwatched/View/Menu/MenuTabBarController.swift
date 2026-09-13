//
//  MenuTabBarController.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import UnwatchedShared

struct MenuTabBarController: UIViewControllerRepresentable {
    let navManager: NavigationManager
    let player: PlayerManager
    let selection: NavigationTab
    let labels: MenuTabLabels
    let onPlayPauseTapped: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(navManager: navManager, player: player, onPlayPauseTapped: onPlayPauseTapped)
    }

    func makeUIViewController(context: Context) -> UITabBarController {
        let coordinator = context.coordinator
        coordinator.environment.values = context.environment

        let controller = UITabBarController()
        controller.delegate = coordinator
        controller.traitOverrides.horizontalSizeClass = .compact
        controller.view.backgroundColor = .clear
        controller.tabs = [
            coordinator.tab(.queue) { QueueTabItemView() },
            coordinator.tab(.inbox) { InboxTabItemView() },
            coordinator.tab(.library) { LibraryView() },
            UITab(title: "", image: nil, identifier: Coordinator.playPauseIdentifier) { _ in UIViewController() },
            UISearchTab { _ in coordinator.host(.search) { SearchView() } }
        ]
        if #available(iOS 27.0, *) {
            controller.prominentTabIdentifier = Coordinator.playPauseIdentifier
        }
        coordinator.apply(labels, to: controller)
        coordinator.select(selection, in: controller)
        return controller
    }

    func updateUIViewController(_ controller: UITabBarController, context: Context) {
        let coordinator = context.coordinator
        coordinator.navManager = navManager
        coordinator.player = player
        coordinator.onPlayPauseTapped = onPlayPauseTapped
        coordinator.updateEnvironment(context.environment)
        coordinator.apply(labels, to: controller)
        coordinator.select(selection, in: controller)
    }
}

@Observable final class MenuTabEnvironment {
    var values = EnvironmentValues()
}

struct MenuTabRoot<Content: View>: View {
    let tab: NavigationTab
    let coordinator: MenuTabBarController.Coordinator
    let content: Content

    var body: some View {
        ScrollViewReader { proxy in
            content
                .environment(\.scrollViewProxy, proxy)
                .onAppear {
                    coordinator.scrollProxies[tab] = proxy
                }
        }
        .scrollEdgeEffectHidden(for: .bottom)
        .scrollEdgeEffectStyle(.soft, for: .top)
        // hosting controllers don't inherit the menu's environment
        .environment(\.self, coordinator.environment.values)
    }
}
#endif
