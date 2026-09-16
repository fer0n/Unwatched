//
//  SpeedMenuButton.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import UIKit
import UnwatchedShared

/// `SpeedMenu`'s menu variant, built on a `UIButton` instead of SwiftUI's `Menu`.
///
/// A SwiftUI `Menu` swallows every pan inside its label as of iOS 27, which leaves the speed
/// scroller in the label unscrollable (a `highPriorityGesture` there doesn't fire either).
/// UIKit's menu button lets the nested scroll view pan while keeping tap-to-open, so the label
/// is hosted inside the button instead. A popover is no alternative: it never shows while the
/// menu sheet is presented, on iOS 26 as well as 27.
struct SpeedMenuButton<Label: View>: UIViewControllerRepresentable {
    @Binding var selectedSpeed: Double
    @Binding var isOn: Bool

    var canSetCustomSpeed = true
    var trimSilence: TrimSilenceOption?
    var accessibilityLabel: String?
    @ViewBuilder var label: () -> Label

    func makeUIViewController(context: Context) -> Controller {
        Controller(rootView: AnyView(label()))
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.update(rootView: AnyView(label()), menu: menu, accessibilityLabel: accessibilityLabel)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: Controller, context: Context) -> CGSize? {
        uiViewController.hostedSize(in: proposal)
    }

    /// Mirrors `SpeedMenuContent`: a stepper, the most common speeds, the channel toggle and trim silence.
    /// Every action keeps the menu open, the way `menuActionDismissBehavior(.disabled)` does there.
    private var menu: UIMenu {
        var children: [UIMenuElement] = [stepperSection, quickSpeedSection, customSettingAction]
        if let trimSilence {
            children.append(trimSilenceElement(trimSilence))
        }
        return UIMenu(children: children)
    }

    /// Deferred: the saved total is read as the menu opens.
    private func trimSilenceElement(_ option: TrimSilenceOption) -> UIDeferredMenuElement {
        UIDeferredMenuElement.uncached { completion in
            let action = UIAction(
                title: String(localized: "trimSilence"),
                subtitle: TrimSilenceStats.current.savedText,
                image: UIImage(
                    systemName: option.isOn.wrappedValue ? Const.trimSilenceSF : Const.trimSilenceOffSF
                ),
                attributes: option.isEnabled ? .keepsMenuPresented : [.disabled, .keepsMenuPresented]
            ) { _ in
                option.isOn.wrappedValue.toggle()
            }
            completion([action])
        }
    }

    private var stepperSection: UIMenu {
        let slowDown = UIAction(
            title: String(localized: "slowDown"),
            image: UIImage(systemName: "minus"),
            attributes: .keepsMenuPresented
        ) { _ in
            if let speed = SpeedHelper.getPreviousSpeed(before: selectedSpeed) {
                selectedSpeed = speed
            }
        }

        // shows the current speed, no action
        let current = UIAction(
            title: SpeedHelper.formatSpeed(selectedSpeed),
            attributes: .keepsMenuPresented
        ) { _ in }

        let speedUp = UIAction(
            title: String(localized: "speedUp"),
            image: UIImage(systemName: "plus"),
            attributes: .keepsMenuPresented
        ) { _ in
            if let speed = SpeedHelper.getNextSpeed(after: selectedSpeed) {
                selectedSpeed = speed
            }
        }

        return UIMenu(
            options: .displayInline,
            preferredElementSize: .small,
            children: [slowDown, current, speedUp]
        )
    }

    private var quickSpeedSection: UIMenu {
        let children = SpeedMenuContent.menuSpeeds.map { speed in
            let action = UIAction(
                title: "\(SpeedHelper.formatSpeed(speed))×",
                attributes: speed == selectedSpeed ? [.disabled, .keepsMenuPresented] : .keepsMenuPresented
            ) { _ in
                selectedSpeed = speed
            }
            return action
        }

        return UIMenu(options: .displayInline, preferredElementSize: .small, children: children)
    }

    private var customSettingAction: UIAction {
        UIAction(
            title: String(localized: "customSpeedSetting"),
            image: UIImage(systemName: isOn ? Const.customPlaybackSpeedSF : Const.customPlaybackSpeedOffSF),
            attributes: canSetCustomSpeed ? .keepsMenuPresented : [.disabled, .keepsMenuPresented]
        ) { _ in
            isOn.toggle()
        }
    }
}

extension SpeedMenuButton {
    /// Holds the menu button with the SwiftUI label hosted inside it.
    final class Controller: UIViewController {
        private let button = UIButton(type: .custom)
        private let host: UIHostingController<AnyView>

        init(rootView: AnyView) {
            host = UIHostingController(rootView: rootView)
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            button.showsMenuAsPrimaryAction = true
            // keeps the stepper on top no matter which way the menu opens
            button.preferredMenuElementOrder = .fixed

            host.view.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = false
            host.view.isUserInteractionEnabled = true
            button.translatesAutoresizingMaskIntoConstraints = false

            addChild(host)
            view.addSubview(button)
            button.addSubview(host.view)
            host.didMove(toParent: self)

            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                button.topAnchor.constraint(equalTo: view.topAnchor),
                button.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                host.view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: button.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
        }

        func update(rootView: AnyView, menu: UIMenu, accessibilityLabel: String?) {
            host.rootView = rootView
            button.menu = menu
            // setting `menu` alone leaves an open menu showing the speed it had when it opened
            button.contextMenuInteraction?.updateVisibleMenu { _ in menu }
            button.accessibilityLabel = accessibilityLabel
        }

        func hostedSize(in proposal: ProposedViewSize) -> CGSize? {
            host.sizeThatFits(in: proposal.replacingUnspecifiedDimensions(by: .init(width: 0, height: 0)))
        }
    }
}
#endif
