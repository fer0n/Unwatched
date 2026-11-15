//
//  PlayerLoadingTimeout.swift
//  Unwatched
//

import SwiftUI
import OSLog
import SwiftData
import UnwatchedShared

struct PlayerLoadingTimeout: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.modelContext) var modelContext

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
                .opacity(showSpinner && error == nil ? 1 : 0)
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    if !isScheduled {
                        overlayButton(Const.reloadCircleSF) {
                            if let reloadAction {
                                reloadAction()
                            } else {
                                PlayerManager.reloadPlayer()
                            }
                        }
                    }
                    if APIError.isRemoved(error) {
                        overlayButton("trash.circle.fill") {
                            player.clearVideo(modelContext)
                        }
                        .accessibilityLabel(Text("clearVideo"))
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.automaticBlack)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.backgroundColor, in: Capsule())
                        #if !os(visionOS)
                        .glassEffect(.regular, in: Capsule())
                        #endif
                        .frame(maxWidth: 280)
                        .padding(.horizontal)
                }
            }
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

    private var isScheduled: Bool {
        if case .scheduled = error as? APIError { true } else { false }
    }

    private var errorMessage: String? {
        if let error = error as? URLError {
            return error.localizedDescription
        }
        guard let error = error as? APIError else { return nil }
        switch error {
        case .ipBlocked:
            return String(localized: "YouTube is blocking this network. Turn off your VPN or try again later.")
        case .scheduled(let date?) where date > .now:
            return String(localized: "Starts \(date.formatted(.relative(presentation: .named)))")
        case .scheduled:
            return String(localized: "This video hasn't started yet.")
        case .signInRequired:
            return String(localized: "Sign in to YouTube to watch this video.")
        case .ageRestricted:
            return String(localized: "This video is age-restricted. Sign in to YouTube to watch it.")
        case .unavailable, .removed:
            return error.errorDescription
        case .httpError, .decodingError, .notAuthenticated, .invalidURL:
            return nil
        }
    }

    private func overlayButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            hapticToggle.toggle()
        } label: {
            Image(systemName: systemImage)
                .resizable()
                .frame(width: 45, height: 45)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.automaticBlack, Color.backgroundColor)
                .fontWeight(.regular)
                #if !os(visionOS)
                // over the video, not on screen while the player's pages move
                .glassEffect(.regular, in: Capsule())
            #endif
        }
        .buttonStyle(.plain)
    }
}
