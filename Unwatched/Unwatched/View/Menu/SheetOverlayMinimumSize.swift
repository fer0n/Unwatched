//
//  SheetOverlayMinimumSize.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SheetOverlayMinimumSize: View {
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos
    @State private var hapticToggle = false

    var body: some View {
        NavigationStack {
            Color.backgroundColor
                .ignoresSafeArea(.all)
                .myNavigationTitle("showMenu")
                .disabled(true)
        }
        .overlay(Color.black.opacity(0.15))
        .background(Color.backgroundColor)
        .onTapGesture {
            if player.limitHeight {
                sheetPos.setDetentMiniPlayer()
            } else {
                sheetPos.setDetentVideoPlayer()
            }
        }
        .overlay(alignment: .topTrailing) {
            playButton
                .padding(14)
        }
        .transparentNavBarWorkaround()
        .opacity(show ? 1 : 0)
        .presentationDragIndicator(.visible)
        .animation(.bouncy(duration: 0.3), value: sheetPos.isMinimumSheet)
    }

    var playButton: some View {
        Button {
            player.handlePlayButton()
            hapticToggle.toggle()
            Signal.interaction("Player.PlayPause.Sheet")
        } label: {
            // resizable pins the circle to the frame; with a font size, .black grows it past the glass
            Image(systemName: player.playPauseSymbol(circleVariant: true))
                .resizable()
                .fontWeight(.black)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.black, .white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .glassEffect(.regular.tint(.white).interactive(), in: .circle)
                .modifier(PlayerTabFade(hiddenOn: .controls))
                // keeps the faded-out button hit tested
                .background(Circle().fill(Color.tappableClear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.playPauseLabel)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }

    var show: Bool {
        sheetPos.isMinimumSheet && player.video != nil
    }
}

#Preview {
    SheetOverlayMinimumSize()
        .environment(PlayerManager())
        .environment(SheetPositionReader())
        .environment(NavigationManager())
}
