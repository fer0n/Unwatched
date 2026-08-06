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
    /// Entries that already have their own button next to the menu
    var inlineItems: [PlayerMenuItem] = []
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
                isCircleVariant: isCircleVariant,
                inlineItems: inlineItems
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

    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player

    @Binding var hapticToggle: Bool
    @Binding var flashSymbol: String?
    @Binding var sleepTimerVM: SleepTimerViewModel

    var showClear = false
    var showWatched = false
    var isCircleVariant = false
    /// Entries that already have their own button next to the menu
    var inlineItems: [PlayerMenuItem] = []

    var body: some View {
        Group {
            #if !os(visionOS)
            SleepTimer(viewModel: $sleepTimerVM, onEnded: player.onSleepTimerEnded)
            #endif

            if playerType == .native && player.availableAudioLanguages.count > 1 {
                Menu {
                    ForEach(player.availableAudioLanguages, id: \.code) { lang in
                        Button {
                            player.selectedAudioLanguage = lang.code
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
                            player.selectedVideoQuality = quality.height
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

            if playerType != .youtubeEmbedded && !player.availableCaptionTracks.isEmpty {
                Menu {
                    Button {
                        player.selectedCaptionTrackId = nil
                        Signal.log("Player.MoreMenu", parameters: ["action": "captions"])
                    } label: {
                        if player.selectedCaptionTrackId == nil {
                            Label("off", systemImage: "checkmark")
                        } else {
                            Text("off")
                        }
                    }
                    ForEach(player.availableCaptionTracks) { track in
                        Button {
                            player.selectedCaptionTrackId = track.id
                            Signal.log("Player.MoreMenu", parameters: ["action": "captions"])
                        } label: {
                            if track.id == player.selectedCaptionTrackId {
                                Label(track.name, systemImage: "checkmark")
                            } else {
                                Text(track.name)
                            }
                        }
                    }
                } label: {
                    Label("captions", systemImage: "captions.bubble.fill")
                }
            }

            if !inlineItems.contains(.copyUrl), let video = player.video {
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
            if !inlineItems.contains(.playerType) {
                Menu {
                    PlayerTypeMenuContent()
                } label: {
                    Label("playerType", systemImage: playerType.systemImage)
                }
            }
            ReloadPlayerButton()
            Divider()

            if browserDisplayMode != .disabled, let url = player.video?.url {
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

/// Entries of the more menu that turn into their own button when the player controls have room for them.
/// `allCases` is the order they're shown in, both in the controls and in the menu.
enum PlayerMenuItem: Int, CaseIterable, Identifiable {
    case copyUrl
    case playerType

    var id: Int { rawValue }

    var systemName: String {
        switch self {
        case .copyUrl: Const.shareSF
        case .playerType: "tv"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .copyUrl: "copyUrl"
        case .playerType: "playerType"
        }
    }
}

/// A more menu entry shown as its own button in the player controls
struct PlayerMenuItemButton: View {
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.previousPlayerType) var previousPlayerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.showExperimentalPlayerTypes) var showExperimentalPlayerTypes: Bool = false
    @Environment(PlayerManager.self) var player
    @State var hapticToggle = false
    @State var flashSymbol: String?

    let item: PlayerMenuItem

    var body: some View {
        Group {
            if item == .playerType {
                Menu {
                    PlayerMenuItemContent(
                        hapticToggle: $hapticToggle,
                        flashSymbol: $flashSymbol,
                        item: item
                    )
                } label: {
                    label
                } primaryAction: {
                    let next = playerType.toggled(previous: previousPlayerType, nativeEnabled: showExperimentalPlayerTypes)
                    if playerType != .native {
                        previousPlayerType = playerType
                    }
                    playerType = next
                    hapticToggle.toggle()
                    Signal.log("Player.MoreMenu", parameters: ["action": "playerTypeToggle"])
                }
            } else {
                Menu {
                    PlayerMenuItemContent(
                        hapticToggle: $hapticToggle,
                        flashSymbol: $flashSymbol,
                        item: item
                    )
                } label: {
                    label
                }
            }
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .environment(\.menuOrder, .fixed)
        .disabled(item == .copyUrl && player.video == nil)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .help(item.label)
        .accessibilityLabel(item.label)
    }

    var label: some View {
        Image(systemName: flashSymbol ?? iconName)
            .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
            .playerToggleModifier(isOn: false, isSmall: true)
            .task(id: flashSymbol) {
                if flashSymbol != nil {
                    try? await Task.sleep(s: 1)
                    withAnimation {
                        flashSymbol = nil
                    }
                }
            }
    }

    var iconName: String {
        item == .playerType
            ? playerType.systemImage
            : item.systemName
    }
}

/// Entries of a single more menu item, kept apart from the button so they're only built on demand.
struct PlayerMenuItemContent: View {
    @Environment(PlayerManager.self) var player

    @Binding var hapticToggle: Bool
    @Binding var flashSymbol: String?

    let item: PlayerMenuItem

    var body: some View {
        switch item {
        case .copyUrl:
            if let video = player.video {
                CopyUrlOptions(
                    asSection: true,
                    video: video,
                    getTimestamp: getTimestamp
                ) {
                    hapticToggle.toggle()
                    flashSymbol = "checkmark"
                }
            }
        case .playerType:
            Section("playerType") {
                PlayerTypeMenuContent()
            }
        }
    }

    func getTimestamp() -> Double {
        player.currentTime ?? player.video?.elapsedSeconds ?? 0
    }
}

/// Player type selection, shared between the more menu and its inline button
struct PlayerTypeMenuContent: View {
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.previousPlayerType) var previousPlayerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.showExperimentalPlayerTypes) var showExperimentalPlayerTypes: Bool = false

    var body: some View {
        ForEach(selectablePlayerTypes, id: \.self) { type in
            Button {
                if playerType != .native {
                    previousPlayerType = playerType
                }
                playerType = type
                Signal.log("Player.MoreMenu", parameters: ["action": "playerType"])
            } label: {
                if type == playerType {
                    Label(type.menuDescription, systemImage: "checkmark")
                } else if type.showsIconInTypeMenu {
                    Label(type.menuDescription, systemImage: type.systemImage)
                } else {
                    Text(type.menuDescription)
                }
            }
        }
    }

    var selectablePlayerTypes: [PlayerTypeSetting] {
        PlayerTypeSetting.allCases.filter {
            $0 != .native || showExperimentalPlayerTypes || playerType == .native
        }
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
