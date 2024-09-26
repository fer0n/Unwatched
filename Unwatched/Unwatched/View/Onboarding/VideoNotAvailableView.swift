//
//  VideoNotAvailableView.swift
//  Unwatched
//

import Foundation
import SwiftUI
import OSLog
import UnwatchedShared

struct VideoNotAvailableView: View {
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?

    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @AppStorage(Const.showTutorial) var showTutorial: Bool = true

    @GestureState private var dragState: CGFloat = 0
    @State private var isDropTarget: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if showTutorial {
                    Spacer()
                }
                Spacer()
                Image("unwatched-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .foregroundStyle(theme.color)
                    .accessibilityLabel("unwatchedLogo")
                Spacer()
                    .frame(height: 30)
                Text("Unwatched")
                    .font(.title)
                    .fontWeight(.heavy)
                Spacer()
            }
            Spacer()

            if showTutorial {
                VStack {
                    AddFeedsMenu(onSuccess: {
                        navManager.navigateTo(.inbox)
                    })
                    .tint(Color.neutralAccentColor)
                    .foregroundStyle(Color.backgroundColor)

                    AddVideosButton()
                        .tint(theme.color)
                        .foregroundStyle(theme.contrastColor)
                }
                .fontWeight(.medium)
                .frame(maxWidth: 300)
                .padding()
            } else {
                Spacer()
                    .frame(height: 30)
            }

            VStack(spacing: showTutorial ? 0 : 5) {
                Image(systemName: "chevron.up")
                    .font(.system(size: showTutorial ? 30 : 50))
                Text(showTutorial ? "skip" : "swipeUpToSelect")
                    .padding(.bottom, 3)
                    .fixedSize()
            }
            .font(.caption)
            .textCase(.uppercase)
            .padding(.top, showTutorial ? 10 : 0)
            .padding(.bottom, 40)
            .onTapGesture {
                showMenu()
                Task {
                    try? await Task.sleep(s: 1)
                    withAnimation {
                        showTutorial = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                Color.backgroundColor
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .black.mix(
                                    with: theme.darkColor,
                                    by: 0.2
                                ),
                                theme.darkColor
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(isDropTarget ? 0.6 : 0.4)
                    .animation(.bouncy(duration: 1.5), value: navManager.showMenu)
            }
        )
        .overlay {
            dropOverlay
        }
        .handleVideoUrlDrop(.queue, isTargeted: handleIsTargeted)
        .ignoresSafeArea(.all)
        .onTapGesture {
            if !showTutorial {
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
        .environment(\.colorScheme, .dark)
    }

    var dropOverlay: some View {
        ZStack {
            if isDropTarget {
                Color.black
                Rectangle()
                    .fill(
                        theme.color.gradient.opacity(0.6)
                    )
                ContentUnavailableView(
                    "dropVideoHere",
                    systemImage: "arrow.down.to.line.circle.fill",
                    description: Text("dropToAddVideo")
                )
            }
        }
        .onTapGesture {
            isDropTarget = false
        }
    }

    func showMenu() {
        if sizeClass == .compact {
            navManager.showMenu = true
        }
    }

    func handleIsTargeted(_ targeted: Bool) {
        isDropTarget = targeted
    }
}

struct VideoNotAvailable_Previews: PreviewProvider {

    static var previews: some View {
        VideoNotAvailableView()
            .modelContainer(DataController.previewContainer)
            .environment(NavigationManager.getDummy())
            .environment(PlayerManager())
            .environment(RefreshManager())
    }
}
