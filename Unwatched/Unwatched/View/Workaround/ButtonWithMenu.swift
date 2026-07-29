//
//  ButtonWithMenu.swift
//  Unwatched
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MenuAction: Identifiable {
    enum Icon {
        case system(String)
        case asset(String)
        case none
    }

    let id = UUID()
    let title: String
    let icon: Icon
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.init(title, icon: .system(systemImage), action: action)
    }

    init(_ title: String, icon: Icon = .none, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
}

/// Actions of separate groups are drawn with a divider between them.
struct MenuActionGroup: Identifiable {
    let id = UUID()
    let title: String?
    let actions: [MenuAction]

    init(title: String? = nil, _ actions: [MenuAction]) {
        self.title = title
        self.actions = actions
    }
}

extension View {
    /// A button whose long press opens a context menu built from `groups`.
    ///
    /// Workaround: on iOS, since 26, SwiftUI's `contextMenu` stops tracking the finger once the
    /// menu is open, so pressing, dragging onto an entry and releasing selects nothing. UIKit's
    /// `UIContextMenuInteraction` is unaffected, so on iOS the view is hosted in a UIKit container
    /// that owns both the menu and the tap — which is why the menu has to be described as data
    /// instead of a `ViewBuilder`. Other platforms render the same data as a plain
    /// `contextMenu`. Verified against iOS 26.5.
    ///
    /// To undo once SwiftUI's version tracks the finger again: make the iOS branch below use
    /// `swiftUIVersion` too, then inline it at the call sites.
    @ViewBuilder
    func buttonWithMenu(
        accessibilityLabel: String,
        groups: [MenuActionGroup],
        onTap: @escaping () -> Void
    ) -> some View {
        #if os(iOS)
        MenuHostingView(
            groups: groups,
            accessibilityLabel: accessibilityLabel,
            onTap: onTap,
            content: { AnyView(self) }
        )
        #else
        swiftUIVersion(accessibilityLabel: accessibilityLabel, groups: groups, onTap: onTap)
        #endif
    }

    private func swiftUIVersion(
        accessibilityLabel: String,
        groups: [MenuActionGroup],
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            self
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .contextMenu {
            ForEach(groups) { group in
                Section(group.title.map { LocalizedStringKey($0) } ?? "") {
                    ForEach(group.actions) { action in
                        Button(action: action.action) {
                            Text(action.title)
                            action.icon.image
                        }
                    }
                }
            }
        }
    }
}

extension MenuAction.Icon {
    @ViewBuilder
    var image: some View {
        switch self {
        case .system(let name): Image(systemName: name)
        case .asset(let name): Image(name)
        case .none: EmptyView()
        }
    }
}

#if os(iOS)
extension MenuAction.Icon {
    var uiImage: UIImage? {
        switch self {
        case .system(let name): UIImage(systemName: name)
        case .asset(let name): UIImage(named: name)
        case .none: nil
        }
    }
}

/// Hosts the SwiftUI content inside a plain UIKit container that owns the context menu
/// interaction. The content is hosted rather than overlaid so the lift animation still has
/// something to show; a `previewProvider` must not be added, custom previews lose the finger
/// the same way SwiftUI's menu does.
private struct MenuHostingView: UIViewRepresentable {
    let groups: [MenuActionGroup]
    let accessibilityLabel: String
    let onTap: () -> Void
    let content: () -> AnyView

    func makeCoordinator() -> Coordinator {
        Coordinator(groups: groups, onTap: onTap)
    }

    func makeUIView(context: Context) -> UIView {
        let container = ActivatableView()
        container.backgroundColor = .clear
        container.isAccessibilityElement = true
        container.accessibilityTraits = .button

        let host = UIHostingController(rootView: content())
        // without this the hosted button gets inset by the safe area, which moves and mismeasures
        // the fullscreen overlay buttons since they sit right at the screen edge
        host.safeAreaRegions = []
        host.view.backgroundColor = .clear
        host.view.accessibilityElementsHidden = true
        host.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: container.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        context.coordinator.host = host

        container.addInteraction(UIContextMenuInteraction(delegate: context.coordinator))
        container.addGestureRecognizer(
            UITapGestureRecognizer(
                target: context.coordinator.tapProxy,
                action: #selector(TapProxy.handleTap)
            )
        )
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.groups = groups
        context.coordinator.onTap = onTap
        context.coordinator.host?.rootView = content()

        uiView.accessibilityLabel = accessibilityLabel
        uiView.accessibilityCustomActions = groups.flatMap(\.actions).map { action in
            UIAccessibilityCustomAction(name: action.title) { _ in
                action.action()
                return true
            }
        }
        (uiView as? ActivatableView)?.onActivate = onTap
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        context.coordinator.host?.sizeThatFits(in: UIView.layoutFittingCompressedSize)
    }

    final class Coordinator: NSObject, UIContextMenuInteractionDelegate {
        var groups: [MenuActionGroup]
        var host: UIHostingController<AnyView>?
        let tapProxy = TapProxy()

        var onTap: () -> Void {
            didSet { tapProxy.onTap = onTap }
        }

        init(groups: [MenuActionGroup], onTap: @escaping () -> Void) {
            self.groups = groups
            self.onTap = onTap
            super.init()
            tapProxy.onTap = onTap
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            configurationForMenuAtLocation location: CGPoint
        ) -> UIContextMenuConfiguration? {
            guard groups.contains(where: { !$0.actions.isEmpty }) else { return nil }

            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                let children: [UIMenuElement] = (self?.groups ?? []).map { group in
                    UIMenu(
                        title: group.title ?? "",
                        options: .displayInline,
                        children: group.actions.map { action in
                            UIAction(title: action.title, image: action.icon.uiImage) { _ in
                                action.action()
                            }
                        }
                    )
                }
                return UIMenu(children: children)
            }
        }
    }
}

/// Routes VoiceOver's activate to the tap handler, which no longer runs through a `Button`.
private final class ActivatableView: UIView {
    var onActivate: (() -> Void)?

    override func accessibilityActivate() -> Bool {
        onActivate?()
        return true
    }
}

/// `@objc` selectors aren't available on the coordinator, so the tap goes through this.
private final class TapProxy: NSObject {
    var onTap: () -> Void = {}

    @objc func handleTap() {
        onTap()
    }
}
#endif
