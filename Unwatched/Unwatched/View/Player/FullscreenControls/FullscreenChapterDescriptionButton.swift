//
//  FullscreenChaptersButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct FullscreenChapterDescriptionButton: View {
    @Namespace private var namespace
    let transitionId = "popoverTransition"

    @Environment(PlayerManager.self) var player
    @State var show = false

    var arrowEdge: Edge
    @Binding var menuOpen: Bool
    var size: CGFloat?
    var showPadding = true

    var body: some View {
        Button {
            if !show {
                show = true
                menuOpen = true
            }
        } label: {
            if let size {
                Image(Const.videoDescriptionCircleSF)
                    .resizable()
                    .modifier(PlayerControlButtonStyle())
                    .frame(width: size, height: size)
            } else {
                Image(Const.videoDescriptionSF)
            }
        }
        .fontWeight(.bold)
        .accessibilityLabel("videoDescription")
        .padding(.horizontal, showPadding ? 15 : 0) // workaround: safearea pushing content in pop over
        .modifier(MyMatchedTransitionSource(id: transitionId, namespace: namespace))
        .popover(isPresented: $show, arrowEdge: arrowEdge) {
            if let video = player.video {
                ZStack {
                    ChapterDescriptionView(
                        video: video,
                        isCompact: true,
                        scrollToCurrent: true,
                        isTransparent: Const.iOS26,
                        showThumbnail: false
                    )
                    .scrollIndicators(.hidden)
                    .frame(
                        minWidth: 200,
                        idealWidth: 350,
                        maxWidth: 350,
                        idealHeight: 500,
                        maxHeight: 500
                    )
                }
                .buttonBorderShape(.automatic)
                .environment(\.colorScheme, .dark)
                .presentationCompactAdaptation(.popover)
                .if(!Const.iOS26) { view in
                    view.presentationBackground(Color.sheetBackground)
                }
                .onDisappear {
                    menuOpen = false
                }
                .fontWeight(nil)
                #if os(iOS) || os(visionOS)
                .apply {
                    if #available(iOS 26.0, *) {
                        $0.navigationTransition(
                            .zoom(sourceID: transitionId, in: namespace)
                        )
                    } else {
                        $0
                    }
                }
                #endif
            }
        }
    }
}

struct MyMatchedTransitionSource: ViewModifier {
    var id: String
    var namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

#Preview {
    FullscreenChapterDescriptionButton(
        arrowEdge: .bottom,
        menuOpen: .constant(true),
        size: 40
    )
    .environment(PlayerManager())
}
