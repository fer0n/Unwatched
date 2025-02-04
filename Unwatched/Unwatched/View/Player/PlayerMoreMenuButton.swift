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

    @State var showDeferDateSelector: Bool = false

    var sleepTimerVM: SleepTimerViewModel
    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var extended = false
    var isCircleVariant = false
    let contentImage: ((Image) -> Content)

    var body: some View {
        Menu {
            SleepTimer(viewModel: sleepTimerVM, onEnded: player.onSleepTimerEnded)
            ReloadPlayerButton()

            bookmarkButton
            copyUrlButton
            deferDateButton

            if let video = player.video, let url = video.url {
                Divider()
                if extended {
                    ExtendedPlayerActions(markVideoWatched: markVideoWatched)
                }

                if UIDevice.isMac {
                    watchInBrowserButton(url)
                }

                Button {
                    openUrl(url)
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
        .help("moreOptions")
        .environment(\.menuOrder, .fixed)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .dateSelectorSheet(
            show: $showDeferDateSelector,
            video: player.video
        ) {
            player.loadTopmostVideoFromQueue(modelContext: modelContext)
        }
    }

    func watchInBrowserButton(_ url: URL) -> some View {
        Button {
            markVideoWatched(false, .nextUp)
            UIApplication.shared.open(url)
        } label: {
            Text("watchInBrowser")
            Image(systemName: "arrow.up.forward.app.fill")
                .padding(5)
        }
    }

    var deferDateButton: some View {
        Button {
            navManager.showMenu = false
            showDeferDateSelector = true
        } label: {
            Text("deferVideo")
            Image(systemName: "clock.fill")
                .padding(5)
        }
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
                Text("removeBookmark")
            } else {
                Text("addBookmark")
            }
            Image(systemName: isBookmarked
                    ? "bookmark.slash.fill"
                    : "bookmark.fill")
                .contentTransition(.symbolEffect(.replace))
        }
    }

    var systemName: String {
        if let flashSymbol {
            return flashSymbol
        } else if sleepTimerVM.isOn {
            return isCircleVariant
                ? "moon.circle.fill"
                : "moon.zzz.fill"
        } else {
            return isCircleVariant
                ? "ellipsis.circle.fill"
                : "ellipsis"
        }
    }

    func openUrl(_ url: URL) {
        navManager.openUrlInApp(.url(url.absoluteString))
        hapticToggle.toggle()
    }

    func toggleBookmark() {
        if let video = player.video {
            if video.bookmarkedDate != nil {
                flashSymbol = isCircleVariant
                    ? "bookmark.circle.fill"
                    : "bookmark.slash.fill"
            } else {
                flashSymbol = isCircleVariant
                    ? "bookmark.circle.fill"
                    : "bookmark.fill"
            }

            VideoService.toggleBookmark(video)
            hapticToggle.toggle()
        }
    }
}

#Preview {
    func doNothing(_ showMenu: Bool, _ source: VideoSource) {}

    return PlayerMoreMenuButton(
        sleepTimerVM: SleepTimerViewModel(),
        markVideoWatched: doNothing) { image in
        image
    }
    .environment(PlayerManager.getDummy())
    .environment(NavigationManager())
}
