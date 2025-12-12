//
//  PlayerMoreMenuButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerMoreMenuButton<Content>: View where Content: View {
    @AppStorage(Const.surroundingEffect) var surroundingEffect = true
    @AppStorage(Const.browserDisplayMode) var browserDisplayMode: BrowserDisplayMode = .asSheet

    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @State var hapticToggle = false
    @State var flashSymbol: String?

    @State var showDeferDateSelector: Bool = false
    @State var sleepTimerVM: SleepTimerViewModel

    var showClear = false
    var showWatched = false
    var isCircleVariant = false
    let contentImage: ((Image) -> Content)

    var body: some View {
        Menu {
            #if !os(visionOS)
            SleepTimer(viewModel: $sleepTimerVM, onEnded: player.onSleepTimerEnded)
            #endif

            if let video = player.video {
                CopyUrlOptions(
                    video: video,
                    getTimestamp: getTimestamp
                ) {
                    hapticToggle.toggle()
                    flashSymbol = isCircleVariant ? "checkmark.circle.fill" : "checkmark"
                }
            }

            bookmarkButton
            deferDateButton

            Divider()
            ExtendedPlayerActions(
                showClear: showClear,
                showWatched: showWatched
            )

            Divider()
            ReloadPlayerButton()
            Divider()

            if browserDisplayMode != .disabled, let url = player.video?.url {
                Button {
                    navManager.showMenu = true
                    openUrl(url)
                } label: {
                    Text("openInAppBrowser")
                    Image(systemName: Const.youtubeSF)
                        .padding(5)
                }
            }

            #if os(visionOS)
            Toggle(isOn: $surroundingEffect) {
                Label("surroundingEffect", systemImage: "circle.lefthalf.filled")
            }
            #endif
        } label: {
            self.contentImage(Image(systemName: systemName))
                .contentTransition(transition)
                .task(id: flashSymbol) {
                    if flashSymbol != nil {
                        try? await Task.sleep(s: 1)
                        withAnimation {
                            flashSymbol = nil
                        }
                    }
                }
        }
        #if os(macOS)
        .buttonStyle(.plain)
        #endif
        .menuIndicator(.hidden)
        .environment(\.menuOrder, .fixed)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .help("moreOptions")
        .accessibilityLabel(String(localized: "moreOptions"))
    }

    var transition: ContentTransition {
        if #available(iOS 18, *) {
            ContentTransition.symbolEffect(.replace.magic(fallback: .replace))
        } else {
            ContentTransition.symbolEffect(.replace)
        }
    }

    var deferDateButton: some View {
        Button {
            navManager.showMenu = false
            navManager.showDeferDateSelector = true
        } label: {
            Text("deferVideo")
            Image(systemName: "clock.fill")
                .padding(5)
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

    func getTimestamp() -> Double {
        player.currentTime ?? player.video?.elapsedSeconds ?? 0
    }
}

#Preview {
    PlayerMoreMenuButton(
        sleepTimerVM: SleepTimerViewModel()) { image in
        image
    }
    .environment(PlayerManager.getDummy())
    .environment(NavigationManager())
}
