//
//  PlayerLoadingTimeout.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct PlayerLoadingTimeout: View {
    @Environment(PlayerManager.self) var player

    @State var showSpinner = false
    @State var showReload = false
    @State var hapticToggle: Bool = false

    var body: some View {
        ZStack {
            ProgressView()
                .opacity(showSpinner ? 1 : 0)
            Button {
                PlayerManager.reloadPlayer()
                hapticToggle.toggle()
            } label: {
                Image(systemName: Const.reloadCircleSF)
                    .resizable()
                    .frame(width: 45, height: 45)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.automaticBlack, Color.backgroundColor)
                    .fontWeight(.regular)
                    .apply {
                        if #available(iOS 26.0, macOS 26.0, *) {
                            $0.glassEffect()
                        } else {
                            $0
                        }
                    }
            }
            .buttonStyle(.plain)
            .opacity(showReload ? 1 : 0)
        }
        .opacity(player.isLoading != nil ? 1 : 0)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .task(id: player.isLoading) {
            if showSpinner {
                showSpinner = false
            }
            if showReload {
                showReload = false
            }

            if player.isLoading != nil {
                do {
                    try await Task.sleep(s: 3)
                    if player.isLoading != nil {
                        showSpinner = true
                    } else {
                        return
                    }
                    try await Task.sleep(s: 10)
                    if player.isLoading != nil {
                        showSpinner = false
                        showReload = true
                    } else {
                        return
                    }
                } catch { }
            }
        }
    }
}
