//
//  PriorityKeyCommands.swift
//  Unwatched
//

import SwiftUI

extension View {
    func priorityKeyCommands() -> some View {
        #if os(iOS)
        background { PriorityKeyCommands() }
        #else
        self
        #endif
    }
}

#if os(iOS)
import Combine

/// iPadOS gives bare arrow keys and space to scrolling and focus before menu shortcuts.
private struct PriorityKeyCommands: View {
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @State private var isEditingText = false

    var body: some View {
        KeyCommandInstaller(isActive: player.video != nil && !navManager.showBrowser && !isEditingText)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onReceive(Self.editingChanges) { isEditingText = $0 }
    }

    private static let editingChanges = Publishers.MergeMany([
        (UITextField.textDidBeginEditingNotification, true),
        (UITextView.textDidBeginEditingNotification, true),
        (UITextField.textDidEndEditingNotification, false),
        (UITextView.textDidEndEditingNotification, false)
    ].map { name, isEditing in
        NotificationCenter.default.publisher(for: name).map { _ in isEditing }
    })
}

private struct KeyCommandInstaller: UIViewRepresentable {
    let isActive: Bool

    func makeUIView(context: Context) -> InstallerView {
        InstallerView()
    }

    func updateUIView(_ view: InstallerView, context: Context) {
        view.isActive = isActive
    }
}

private final class InstallerView: UIView {
    var isActive = false {
        didSet { apply() }
    }
    private weak var host: UIViewController?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        apply()
    }

    private func apply() {
        let target = isActive ? window?.rootViewController : nil
        guard target !== host else { return }
        commands.forEach { host?.removeKeyCommand($0) }
        commands.forEach { target?.addKeyCommand($0) }
        host = target
    }

    private let commands: [UIKeyCommand] = PlayerShortcut.allCases.flatMap { shortcut in
        shortcut.keyboardShortcuts.compactMap { combo in
            guard combo.modifier.isEmpty, let input = combo.key.systemClaimedInput else { return nil }
            let command = UIKeyCommand(
                action: #selector(UIViewController.triggerPlayerShortcut),
                input: input,
                propertyList: shortcut.rawValue
            )
            command.wantsPriorityOverSystemBehavior = true
            return command
        }
    }
}

private extension UIViewController {
    @objc func triggerPlayerShortcut(_ sender: UIKeyCommand) {
        guard let rawValue = sender.propertyList as? String else { return }
        PlayerShortcut(rawValue: rawValue)?.trigger()
    }
}

private extension KeyEquivalent {
    var systemClaimedInput: String? {
        switch self {
        case .leftArrow: UIKeyCommand.inputLeftArrow
        case .rightArrow: UIKeyCommand.inputRightArrow
        case .upArrow: UIKeyCommand.inputUpArrow
        case .downArrow: UIKeyCommand.inputDownArrow
        case .space: " "
        default: nil
        }
    }
}
#endif
