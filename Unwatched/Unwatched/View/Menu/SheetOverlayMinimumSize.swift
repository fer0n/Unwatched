//
//  SheetOverlayMinimumSize.swift
//  Unwatched
//

import SwiftUI

struct SheetOverlayMinimumSize: View {
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos

    var currentTab: NavigationTab

    var body: some View {
        let show = sheetPos.isMinimumSheet && player.video != nil

        NavigationStack {
            Color.backgroundColor
                .ignoresSafeArea(.all)
                .myNavigationTitle(currentTab.stringKey, showBack: false)
                .toolbar {
                    RefreshToolbarButton()
                }
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
        .transparentNavBarWorkaround()
        .opacity(show ? 1 : 0)
        .presentationDragIndicator(show ? .visible : .hidden)
        .animation(.bouncy(duration: 0.3), value: sheetPos.isMinimumSheet)
    }
}

#Preview {
    SheetOverlayMinimumSize(
        currentTab: .queue
    )
    .environment(RefreshManager())
    .environment(SheetPositionReader())
}
