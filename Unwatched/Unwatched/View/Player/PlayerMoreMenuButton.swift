//
//  PlayerMoreMenuButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerMoreMenuButton<Content>: View where Content: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @State var hapticToggle = false
    @State var flashSymbol: String?

    var sleepTimerVM: SleepTimerViewModel
    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var extended = false
    let contentImage: ((Image) -> Content)

    var body: some View {
        Menu {
            SleepTimer(viewModel: sleepTimerVM, onEnded: player.onSleepTimerEnded)
            ReloadPlayerButton()

            bookmarkButton
            copyUrlButton

            if let video = player.video, let url = video.url {
                Divider()
                if extended {
                    Button("markWatched", systemImage: "checkmark") {
                        markVideoWatched(true, .nextUp)
                    }

                    Button("clearVideo", systemImage: Const.clearNoFillSF) {
                        player.clearVideo(modelContext)
                    }
                }

                Button {
                    navManager.openUrlInApp(.url(url.absoluteString))
                    navManager.showMenu = true
                    UserDefaults.standard.set(false, forKey: Const.hideControlsFullscreen)
                } label: {
                    Text("openInAppBrowser")
                    Image(systemName: Const.appBrowserSF)
                        .padding(5)
                }
            }
        } label: {
            self.contentImage(Image(systemName: systemName))
                .contentTransition(.symbolEffect(.replace))
                .task(id: flashSymbol) {
                    if flashSymbol != nil {
                        try? await Task.sleep(s: 0.8)
                        withAnimation {
                            flashSymbol = nil
                        }
                    }
                }
        }
        .environment(\.menuOrder, .fixed)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }

    @ViewBuilder
    var copyUrlButton: some View {
        if let video = player.video, let url = video.url {
            Button {
                UIPasteboard.general.string = url.absoluteString
                flashSymbol = "checkmark"
                hapticToggle.toggle()
            } label: {
                Text("copyUrl")
                Image(systemName: "document.on.document.fill")
            }
        }
    }

    var bookmarkButton: some View {
        Button(action: toggleBookmark) {
            let isBookmarked = player.video?.bookmarkedDate != nil
            if isBookmarked {
                Text("bookmarked")
            } else {
                Text("addBookmark")
            }
            Image(systemName: isBookmarked
                    ? "bookmark.fill"
                    : "bookmark.slash.fill")
                .contentTransition(.symbolEffect(.replace))
        }
    }

    var systemName: String {
        if let flashSymbol {
            flashSymbol
        } else if sleepTimerVM.isOn {
            "moon.zzz.fill"
        } else {
            "ellipsis"
        }
    }

    func toggleBookmark() {
        if let video = player.video {
            if video.bookmarkedDate != nil {
                flashSymbol = "bookmark.slash"
            } else {
                flashSymbol = "bookmark.fill"
            }

            VideoService.toggleBookmark(video)
            hapticToggle.toggle()
        }
    }
}

#Preview {
    PlayerMoreMenuButton(
        sleepTimerVM: SleepTimerViewModel(),
        markVideoWatched: { _, _ in
        }) { image in
        image
    }
    .environment(PlayerManager.getDummy())
    .environment(NavigationManager())
}
