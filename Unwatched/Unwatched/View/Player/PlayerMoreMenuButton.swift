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
    @AppStorage(Const.preferPlayerType) var preferPlayerType: Bool = false

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

            if !inlineItems.contains(.copyUrl), let video = player.video {
                CopyUrlOptions(
                    video: video,
                    getTimestamp: getTimestamp
                ) {
                    hapticToggle.toggle()
                    flashSymbol = isCircleVariant ? "checkmark.circle.fill" : "checkmark"
                }
            }

            if !inlineItems.contains(.bookmark) {
                bookmarkButton
            }
            deferDateButton

            Divider()
            ExtendedPlayerActions(
                showClear: showClear,
                showWatched: showWatched
            )

            Divider()
            if !preferPlayerType && !inlineItems.contains(.playerType) {
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
enum PlayerMenuItem: Int, Identifiable {
    case copyUrl
    case bookmark
    case playerType

    var id: Int { rawValue }

    /// The entries shown as buttons, in order; the rest stay inside the menu
    static func inlineItems(preferPlayerType: Bool) -> [PlayerMenuItem] {
        [.copyUrl, preferPlayerType ? .playerType : .bookmark]
    }

    var systemName: String {
        switch self {
        case .copyUrl: Const.shareSF
        case .bookmark: "bookmark"
        case .playerType: "tv"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .copyUrl: "copyUrl"
        case .bookmark: "addBookmark"
        case .playerType: "playerType"
        }
    }
}

/// A more menu entry shown as its own button in the player controls
struct PlayerMenuItemButton: View {
    @Environment(PlayerManager.self) var player
    @State var hapticToggle = false
    @State var flashSymbol: String?

    let item: PlayerMenuItem

    var body: some View {
        Group {
            if item == .playerType {
                PlayerTypeButton { image in
                    image.playerToggleModifier(isOn: false, isSmall: true)
                }
            } else if item == .bookmark {
                Button(action: toggleBookmark) {
                    bookmarkLabel
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
        .disabled(item != .playerType && player.video == nil)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
    }

    var isBookmarked: Bool {
        player.video?.bookmarkedDate != nil
    }

    var accessibilityLabel: LocalizedStringKey {
        item == .bookmark && isBookmarked ? "removeBookmark" : item.label
    }

    /// Shows the current state rather than what tapping does, unlike the menu entry
    var bookmarkLabel: some View {
        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
            .animation(.default, value: isBookmarked)
            .playerToggleModifier(isOn: isBookmarked, isSmall: true)
    }

    func toggleBookmark() {
        guard let video = player.video else { return }
        VideoService.toggleBookmark(video)
        hapticToggle.toggle()
        Signal.log("Player.MoreMenu", parameters: ["action": "bookmark"])
    }

    var label: some View {
        Image(systemName: flashSymbol ?? item.systemName)
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
}

/// Tapping toggles between the last two player types, long pressing opens the menu
struct PlayerTypeButton<Content: View>: View {
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.previousPlayerType) var previousPlayerType: PlayerTypeSetting = .youtubeEmbedded

    @State var hapticToggle = false
    @State var animateSwitch = false
    @State var switchManager = PlayerSwitchManager.shared

    /// Appended below the player types, for the actions of a button this one replaces
    var extraGroups: [MenuActionGroup] = []
    @ViewBuilder let contentImage: (Image) -> Content

    var body: some View {
        contentImage(Image(systemName: playerType.systemImage))
            .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
            // @AppStorage writes aren't animated, so without this the symbol would swap instantly
            .animation(.default, value: playerType)
            .symbolEffect(.bounce, options: .repeat(.periodic(delay: 0.4)), isActive: animateSwitch)
            .buttonWithMenu(
                accessibilityLabel: String(localized: "playerType"),
                groups: menuGroups,
                onTap: toggle
            )
            .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
            // repeated discrete effect rather than an indefinite one (`.breathe`): ending the
            // switch drops out of those mid-movement. The delay lets `.replace` play out first.
            .task(id: switchManager.isSwitching) {
                guard switchManager.isSwitching else {
                    animateSwitch = false
                    return
                }
                try? await Task.sleep(s: 0.35)
                if !Task.isCancelled {
                    animateSwitch = true
                }
            }
    }

    var menuGroups: [MenuActionGroup] {
        [
            MenuActionGroup(title: String(localized: "playerType"), PlayerTypeSetting.allCases.map { type in
                MenuAction(
                    type.menuDescription,
                    icon: type == playerType
                        ? .system("checkmark")
                        : type.showsIconInTypeMenu
                        ? .system(type.systemImage)
                        : .none
                ) {
                    select(type)
                }
            })
        ] + extraGroups
    }

    func select(_ type: PlayerTypeSetting) {
        if playerType != .native {
            previousPlayerType = playerType
        }
        playerType = type
        Signal.log("Player.MoreMenu", parameters: ["action": "playerType"])
    }

    func toggle() {
        // the icon already shows where the switch is headed, so tapping again means "never mind"
        if switchManager.isSwitching {
            switchManager.cancel()
            hapticToggle.toggle()
            return
        }
        let next = playerType.toggled(previous: previousPlayerType)
        if playerType != .native {
            previousPlayerType = playerType
        }
        playerType = next
        hapticToggle.toggle()
        Signal.log("Player.MoreMenu", parameters: ["action": "playerTypeToggle"])
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
        case .bookmark:
            EmptyView()
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

    var body: some View {
        ForEach(PlayerTypeSetting.allCases, id: \.self) { type in
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
}

#Preview {
    PlayerMoreMenuButton(
        sleepTimerVM: SleepTimerViewModel()) { image in
        image
    }
    .environment(PlayerManager.getDummy())
    .environment(NavigationManager())
}
