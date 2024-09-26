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
                Image(systemName: Const.reloadSF)
                    .foregroundStyle(.automaticWhite)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(7)
                    .background {
                        Circle()
                            .fill(.automaticBlack)
                    }
            }
            .opacity(showReload ? 1 : 0)
        }
        .opacity(player.isLoading ? 1 : 0)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .task(id: player.isLoading) {
            if showSpinner {
                showSpinner = false
            }
            if showReload {
                showReload = false
            }

            if player.isLoading {
                do {
                    try await Task.sleep(s: 3)
                    if player.isLoading {
                        showSpinner = true
                    } else {
                        return
                    }
                    try await Task.sleep(s: 10)
                    if player.isLoading {
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
