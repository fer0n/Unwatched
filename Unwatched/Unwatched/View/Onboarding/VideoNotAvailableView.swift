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
    @Environment(SheetPositionReader.self) var sheetPos

    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @AppStorage(Const.showTutorial) var showTutorial: Bool = true

    @GestureState private var dragState: CGFloat = 0
    @State private var isDropTarget: Bool = false

    var body: some View {
        GeometryReader { proxy in
            Image(systemName: "checkmark.rectangle.stack.fill")
                .resizable()
                .scaledToFit()
                .symbolVariant(.fill)
                .fontWeight(.black)
                .frame(width: proxy.size.width * 0.3)
                .foregroundStyle(theme.color)
                .opacity(0.8)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
                .opacity(sheetPos.swipedBelow ? 1 : 0)
                .animation(.bouncy, value: sheetPos.swipedBelow)
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
                                theme.darkColor,
                                .black.myMix(
                                    with: theme.darkColor,
                                    by: 0.8
                                ),
                                .black
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .animation(.bouncy, value: sheetPos.swipedBelow)
                    .opacity(!sheetPos.swipedBelow ? 0.7 : isDropTarget ? 0.6 : 1)
                    .animation(.default.speed(0.5), value: sheetPos.swipedBelow)
            }
            .edgesIgnoringSafeArea(.all)
            .padding(.bottom, -120)
        )
        .overlay {
            dropOverlay
        }
        .onTapGesture {
            showMenu()
        }
        .opacity(0.7)
        .handleVideoUrlDrop(.queue, isTargeted: handleIsTargeted)
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
            sheetPos.setDetentVideoPlayer()
        }
    }

    func handleIsTargeted(_ targeted: Bool) {
        isDropTarget = targeted
    }
}

struct VideoNotAvailable_Previews: PreviewProvider {

    static var previews: some View {
        VideoNotAvailableView()
            .modelContainer(DataProvider.previewContainer)
            .environment(NavigationManager())
            .environment(PlayerManager())
            .environment(RefreshManager())
            .environment(SheetPositionReader())
    }
}
