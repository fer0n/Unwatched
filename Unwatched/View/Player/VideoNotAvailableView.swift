//
//  VideoNotAvailableView.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct VideoNotAvailableView: View {
    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) private var player
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?

    @GestureState private var dragState: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            ContentUnavailableView(
                "noVideoSelected",
                systemImage: "play.rectangle.fill",
                description: Text("swipeUpToSelecte")
            )
            Spacer()
            Image(systemName: "chevron.up")
                .font(.system(size: 50))
                .padding(40)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                Color.backgroundColor
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: navManager.showMenu ?
                                                [.black, .black] :
                                                [.teal, .green]),
                            startPoint: .top,
                            endPoint: .bottom)

                    )
                    .opacity(0.4)
                    .animation(.bouncy(duration: 1.5), value: navManager.showMenu)
            }
        )
        .ignoresSafeArea(.all)
        .onTapGesture {
            showMenu()
        }
        .onAppear {
            if player.video == nil {
                showMenu()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .updating($dragState) { value, state, _ in
                    state = value.translation.height
                    if state < -30 {
                        showMenu()
                    }
                }
        )
    }

    func showMenu() {
        if sizeClass == .compact {
            navManager.showMenu = true
        }
    }
}

struct VideoNotAvailable_Previews: PreviewProvider {

    static var previews: some View {
        VideoNotAvailableView()
            .modelContainer(DataController.previewContainer)
            .environment(NavigationManager.getDummy())
    }
}
