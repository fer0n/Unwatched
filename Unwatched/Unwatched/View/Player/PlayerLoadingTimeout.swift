//
//  PlayerLoadingTimeout.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct PlayerLoadingTimeout: View {
    @Environment(PlayerManager.self) var player

    var error: Error?
    var reloadAction: (() -> Void)?
    var spinnerDelay: Double = 3

    /// When `true`, the reload button appears after a loading timeout even without an explicit error.
    /// Disable for players that report a reliable `error` on actual failure (e.g. the AV player),
    /// so a slow-but-successful load doesn't surface a spurious reload overlay.
    var reloadOnTimeout: Bool = true

    @State var showSpinner = false
    @State var showReload = false
    @State var hapticToggle: Bool = false

    var body: some View {
        ZStack {
            ProgressView()
                .opacity(showSpinner ? 1 : 0)
            Button {
                if let reloadAction {
                    reloadAction()
                } else {
                    PlayerManager.reloadPlayer()
                }
                hapticToggle.toggle()
            } label: {
                Image(systemName: Const.reloadCircleSF)
                    .resizable()
                    .frame(width: 45, height: 45)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.automaticBlack, Color.backgroundColor)
                    .fontWeight(.regular)
                    #if !os(visionOS)
                    .apply {
                        if #available(iOS 26.0, macOS 26.0, *) {
                            $0.glassEffect()
                        } else {
                            $0
                        }
                    }
                #endif
            }
            .buttonStyle(.plain)
            .opacity(showReload ? 1 : 0)
        }
        .opacity(player.isLoading != nil || error != nil ? 1 : 0)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .task(id: player.isLoading) {
            showSpinner = false
            if error == nil { showReload = false }

            if player.isLoading != nil {
                do {
                    if spinnerDelay > 0 {
                        try await Task.sleep(s: spinnerDelay)
                    }
                    guard player.isLoading != nil else { return }
                    showSpinner = true
                    guard reloadOnTimeout else { return }
                    try await Task.sleep(s: 10)
                    guard player.isLoading != nil else { return }
                    showSpinner = false
                    showReload = true
                } catch {}
            }
        }
        .task(id: error != nil) {
            if error != nil {
                showSpinner = false
                showReload = true
            } else if player.isLoading == nil {
                showReload = false
            }
        }
    }
}
