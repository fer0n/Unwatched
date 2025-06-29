//
//  AppStateObserver.swift
//  Unwatched
//

#if os(macOS)
import SwiftUI
import UnwatchedShared
import AppKit

@Observable
class AppStateObserver {

    @MainActor
    var isActive: Bool = true

    @ObservationIgnored private var resignObserver: Any?
    @ObservationIgnored private var becomeObserver: Any?

    init() {
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isActive = false
        }
        becomeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isActive = true
        }
    }

    deinit {
        if let resignObserver = resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
        if let becomeObserver = becomeObserver {
            NotificationCenter.default.removeObserver(becomeObserver)
        }
    }
}

struct MacOSActiveStateChange: ViewModifier {
    @State var appStateObserver = AppStateObserver()

    var handleBecomeActive: (() -> Void)?
    var handleResignActive: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .onChange(of: appStateObserver.isActive) {
                appStateObserver.isActive ? handleBecomeActive?() : handleResignActive?()
            }
    }
}

extension View {
    func macOSActiveStateChange(
        handleBecomeActive: (() -> Void)? = nil,
        handleResignActive: (() -> Void)? = nil
    ) -> some View {
        self.modifier(MacOSActiveStateChange(
            handleBecomeActive: handleBecomeActive,
            handleResignActive: handleResignActive
        ))
    }
}
#endif
