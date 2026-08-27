//
//  PlayerMoreMenuButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerMoreMenuButton<Content>: View where Content: View {
    @State var hapticToggle = false
    @State var flashSymbol: String?

    @State var sleepTimerVM: SleepTimerViewModel

    var showClear = false
    var showWatched = false
    var isCircleVariant = false
    let contentImage: ((Image) -> Content)

    var body: some View {
        Menu {
            // its own view so the entries are only built when the menu is opened: the player
            // controls construct this button often enough that building them eagerly costs frames
            PlayerMoreMenuContent(
                hapticToggle: $hapticToggle,
                flashSymbol: $flashSymbol,
                sleepTimerVM: $sleepTimerVM,
                showClear: showClear,
                showWatched: showWatched,
                isCircleVariant: isCircleVariant
            )
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
        #if !os(visionOS)
        .buttonStyle(.plain)
        #endif
        .menuIndicator(.hidden)
        .environment(\.menuOrder, .fixed)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .help("moreOptions")
        .accessibilityLabel(String(localized: "moreOptions"))
    }

    var transition: ContentTransition {
        ContentTransition.symbolEffect(.replace.magic(fallback: .replace))
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
}

/// Entries of the player's more menu, kept apart from the button so they're only built on demand.
struct PlayerMoreMenuContent: View {
    @AppStorage(Const.surroundingEffect) var surroundingEffect = true
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.browserDisplayMode) var browserDisplayMode: BrowserDisplayMode = .inApp
    @AppStorage(Const.preferPlayerType) var preferPlayerType: Bool = false
    @AppStorage(Const.trimSilence) var trimSilence: Bool = false

    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player

    @Binding var hapticToggle: Bool
    @Binding var flashSymbol: String?
    @Binding var sleepTimerVM: SleepTimerViewModel

    var showClear = false
    var showWatched = false
    var isCircleVariant = false

    var body: some View {
        Group {
            #if !os(visionOS)
            SleepTimer(viewModel: $sleepTimerVM, onEnded: player.onSleepTimerEnded)
            #endif

            if playerType == .native && player.availableAudioLanguages.count > 1 {
                Menu {
                    ForEach(player.availableAudioLanguages, id: \.code) { lang in
                        Button {
                            player.setAudioLanguage(lang.code)
                            Signal.log("Player.MoreMenu", parameters: ["action": "audioLanguage"])
                        } label: {
                            if lang.code == player.selectedAudioLanguage {
                                Label(lang.name, systemImage: "checkmark")
                            } else {
                                Text(lang.name)
                            }
                        }
                    }
                } label: {
                    Label("audioLanguage", systemImage: "globe")
                }
            }

            if playerType == .native && player.availableVideoQualities.count > 1 {
                Menu {
                    ForEach(player.availableVideoQualities, id: \.height) { quality in
                        Button {
                            player.setVideoQuality(quality.height)
                            Signal.log("Player.MoreMenu", parameters: ["action": "videoQuality"])
                        } label: {
                            if quality.height == player.selectedVideoQuality {
                                Label(quality.label, systemImage: "checkmark")
                            } else {
                                Text(quality.label)
                            }
                        }
                    }
                } label: {
                    Label("videoQuality", systemImage: "film.fill")
                }
            }

            // audio episodes have their own button in PiP's spot; the engine rebuilds its composition,
            // so this goes through the player rather than straight to `@AppStorage`
            if player.video?.isPodcast == true, !player.isAudioOnly {
                Toggle(isOn: Binding(
                    get: { trimSilence },
                    set: { player.setTrimSilence($0) }
                )) {
                    Label("trimSilence", systemImage: "waveform")
                }
            }

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
            // a podcast episode plays natively whatever the setting says
            if !preferPlayerType, player.video?.isPodcast != true {
                Menu {
                    PlayerTypeMenuContent()
                } label: {
                    Label("playerType", systemImage: playerType.systemImage)
                }
            }
            ReloadPlayerButton()
            Divider()

            if browserDisplayMode != .disabled, let video = player.video, !video.isPodcast, let url = video.url {
                Button {
                    navManager.showMenu = true
                    openUrl(url)
                    Signal.log("Player.MoreMenu", parameters: ["action": "openInBrowser"])
                } label: {
                    Text("openInAppBrowser")
                    Image(systemName: Const.viewOnYouTubeSF)
                        .padding(5)
                }
            }

            #if os(visionOS)
            Toggle(isOn: $surroundingEffect) {
                Label("surroundingEffect", systemImage: "circle.lefthalf.filled")
            }
            #endif
        }
    }

    var deferDateButton: some View {
        Button {
            navManager.showMenu = false
            navManager.showDeferDateSelector = true
            Signal.log("Player.MoreMenu", parameters: ["action": "defer"])
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
            Signal.log("Player.MoreMenu", parameters: ["action": "bookmark"])
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
