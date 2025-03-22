//
//  CursorHideModifier.swift
//  Unwatched
//

import SwiftUI

struct CursorHideModifier: ViewModifier {
    private let hideDelay: TimeInterval
    private let isEnabled: Bool
    private var onChange: ((Bool) -> Void)?

    @State private var task: Task<Void, Never>?
    @State private var isVisible = true

    init(hideAfter delay: TimeInterval = 2.0, isEnabled: Bool = true, onChange: ((Bool) -> Void)?) {
        self.hideDelay = delay
        self.isEnabled = isEnabled
        self.onChange = onChange
    }

    func body(content: Content) -> some View {
        content
            .onDisappear {
                task?.cancel()
            }
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    if !isEnabled { return }
                    task?.cancel()
                    handleChange(true)
                    task = Task {
                        do {
                            try await Task.sleep(for: .seconds(hideDelay))
                            #if os(macOS)
                            NSCursor.setHiddenUntilMouseMoves(true)
                            #endif
                            handleChange(false)
                        } catch { }
                    }
                case .ended:
                    break
                }
            }
    }

    func handleChange(_ isVisible: Bool) {
        if isVisible != self.isVisible {
            onChange?(isVisible)
            self.isVisible = isVisible
        }
    }
}

extension View {
    func hideCursorOnInactive(
        after delay: TimeInterval = 2.0,
        isEnabled: Bool = true,
        onChange: ((Bool) -> Void)? = nil
    ) -> some View {
        modifier(CursorHideModifier(hideAfter: delay, isEnabled: isEnabled, onChange: onChange))
    }
}
