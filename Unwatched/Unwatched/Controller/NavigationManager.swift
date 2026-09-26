//
//  NavigationManager.swift
//  Unwatched
//

import Foundation
import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

@Observable class NavigationManager: Codable {
    @MainActor
    static let shared: NavigationManager = {
        NavigationManager.load()
    }()

    var showMenu = false
    var showBrowser = false
    var openWindow: OpenWindowAction?
    var columnVisibility: NavigationSplitViewVisibility = .automatic
    var showDeferDateSelector = false
    var showPremiumOffer = false
    var showOnboarding = false
    var showSettingsSplash = false

    var isMacosFullscreen = false

    var playerTab: ControlNavigationTab = .controls
    @ObservationIgnored var scrollToCurrentChapter = false

    var tab = NavigationTab.queue

    var askForReviewPoints = 0
    var askForReviewCount = 0

    var presentedQueue = [MenuRoute]()
    var presentedInbox = [MenuRoute]()
    // Transient (not persisted) — the Search tab's result page and the channel previews on top of it.
    var presentedSearch = [SearchRoute]()
    // Toggled (e.g. via the "Search" home-screen quick action) to request the
    // Search tab focus its search field. SearchView observes and consumes it.
    var pendingSearchFocus = false
    // seeded for the first switch to the tab, before SearchView exists to update it
    var searchTabShouldAutoFocus = !UserDefaults.standard.bool(forKey: Const.showSearchRecommendations)
    var presentedLibrary = NavigationPath()

    @ObservationIgnored var topListItemId: String?
    @ObservationIgnored private var lastTabTwiceDate: Date?
    var lastLibrarySubscriptionId: PersistentIdentifier?

    /// The slice on screen; what plays next is latched on `PlayerManager` instead.
    var queueTag: QueueTagSelection = .all

    func queueFilter(_ context: ModelContext) -> QueueFilter {
        QueueFilter(queueTag, context)
    }

    init() { }

    static func load() -> NavigationManager {
        if let savedNavManager = UserDefaults.standard.data(forKey: Const.navigationManager),
           let loadedNavManager = try? JSONDecoder().decode(NavigationManager.self, from: savedNavManager) {
            return loadedNavManager
        } else {
            Log.info("navManager not found")
            let newNavigationManager = NavigationManager()
            newNavigationManager.showMenu = true
            return newNavigationManager
        }
    }

    func save() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            UserDefaults.standard.set(encoded, forKey: Const.navigationManager)
        }
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: NavManagerCodingKeys.self)

        showMenu = try container.decode(Bool.self, forKey: .showMenu)
        tab = try container.decode(NavigationTab.self, forKey: .tab)
        askForReviewPoints = try container.decode(Int.self, forKey: .askForReviewPoints)
        askForReviewCount = try container.decodeIfPresent(Int.self, forKey: .askForReviewCount) ?? 0

        let decoded = try container.decode(NavigationPath.CodableRepresentation.self, forKey: .presentedLibrary)
        presentedLibrary = NavigationPath(decoded)

        let legacyInbox = try? container.decodeIfPresent(
            [SendableSubscription].self,
            forKey: .presentedSubscriptionInbox
        )
        presentedInbox = (try? container.decodeIfPresent([MenuRoute].self, forKey: .presentedInbox))
            ?? legacyInbox?.map(MenuRoute.subscription)
            ?? []
        // `queueTagId` is what versions before the tag slices wrote. `try?`, so a selection this
        // build can no longer read costs the tag and not the whole navigation state.
        let legacyTagId = try container.decodeIfPresent(PersistentIdentifier.self, forKey: .queueTagId)
        let decodedTag = (try? container.decodeIfPresent(QueueTagSelection.self, forKey: .queueTag)) ?? nil
        queueTag = decodedTag ?? QueueTagSelection(tagId: legacyTagId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: NavManagerCodingKeys.self)

        try container.encode(showMenu, forKey: .showMenu)
        try container.encode(tab, forKey: .tab)
        try container.encode(askForReviewPoints, forKey: .askForReviewPoints)
        try container.encode(askForReviewCount, forKey: .askForReviewCount)

        if let representation = presentedLibrary.codable {
            try container.encode(representation, forKey: .presentedLibrary)
        }
        try container.encode(presentedInbox, forKey: .presentedInbox)
        try container.encode(queueTag, forKey: .queueTag)
    }

    /// The menu is a sheet on iPhone, and only one sheet shows at a time
    func presentOnboarding() {
        showMenu = false
        showOnboarding = true
    }

    func presentSettingsSplash() {
        showMenu = false
        showSettingsSplash = true
    }

    func dismissSettingsSplash() {
        showSettingsSplash = false
        showMenu = true
    }

    func navigateTo(_ tab: NavigationTab) {
        if self.tab != tab {
            self.tab = tab
        }
        if !showMenu {
            showMenu = true
        }
        if isSidebarHidden {
            toggleSidebar(show: true)
        }
        Task { @MainActor in
            if SheetPositionReader.shared.isMinimumSheet {
                SheetPositionReader.shared.setDetentVideoPlayer()
            }
        }
    }

    func navigateToQueue() {
        if tab != .queue {
            self.tab = .queue
        } else {
            presentedQueue.removeAll()
        }
    }

    func setScrollId(_ value: String?, _ differentiator: String = "") {
        topListItemId = NavigationManager.getScrollId(value, differentiator)
    }

    static func getScrollId(_ value: String?, _ differentiator: String = "") -> String {
        "scrollId-\(differentiator)-\(value ?? "")"
    }

    func handleTappedTwice() -> Bool {
        var isOnTopView = false
        switch tab {
        case .inbox:
            isOnTopView = presentedInbox.isEmpty
        case .queue:
            isOnTopView = presentedQueue.isEmpty
        case .library:
            isOnTopView = presentedLibrary.isEmpty
        case .browser:
            Task { @MainActor in
                BrowserManager.shared.loadUrl(BrowserUrl.youtubeStartPage.getUrl)
            }
        case .search:
            isOnTopView = presentedSearch.isEmpty
        }

        return isOnTopView
    }

    func clearNavigationStack(_ tab: NavigationTab) {
        switch tab {
        case .inbox:
            presentedInbox.removeAll()
        case .queue:
            presentedQueue.removeAll()
        case .library:
            lastLibrarySubscriptionId = nil
            presentedLibrary = NavigationPath()
        case .search:
            presentedSearch.removeAll()
        case .browser:
            break
        }
    }

    @MainActor
    func openUrlInApp(_ url: BrowserUrl?) {
        // "Open Links" setting: route "View on YouTube" links to the external browser
        // when chosen, do nothing when disabled, otherwise show them in the in-app
        // browser sheet. The Search tab's result fallback bypasses this and always uses
        // the in-app browser directly.
        let browserMode = BrowserDisplayMode.setting

        if browserMode == .disabled {
            return
        }

        if browserMode == .external, let resolvedUrl = url?.getUrl {
            let player = PlayerManager.shared
            let enablePip = !player.pipEnabled && player.isPlaying
            if enablePip {
                // Keep playback visible while leaving the app.
                player.setPip(true)
                Task {
                    try? await Task.sleep(for: .seconds(0.2))
                    UrlService.open(resolvedUrl)
                }
            } else {
                UrlService.open(resolvedUrl)
            }
            return
        }

        openBrowser(url)
    }

    @MainActor
    func openBrowser(_ url: BrowserUrl?) {
        UserDefaults.standard.set(false, forKey: Const.hideControlsFullscreen)
        if let url {
            BrowserManager.shared.loadUrl(url.getUrl)
        }
        showBrowser = true
        showMenu = true
        #if os(macOS)
        openWindow?(id: Const.windowBrowser)
        #endif
    }

    @MainActor
    func handlePlay() {
        let rotateOnPlay = UserDefaults.standard.bool(forKey: Const.rotateOnPlay)
        let returnToQueue = Const.returnToQueue.bool ?? true

        if showBrowser != false {
            showBrowser = false
        }

        if (Const.hideMenuOnPlay.bool ?? true) || (Device.isIphone && rotateOnPlay) {
            #if os(macOS)
            toggleSidebar(show: false)
            #else
            withAnimation {
                if Device.isIpad || Device.isVision {
                    UserDefaults.standard.set(true, forKey: Const.hideControlsFullscreen)
                }
                SheetPositionReader.shared.setDetentMinimumSheet()
            }
            #endif
        }

        if SheetPositionReader.shared.landscapeFullscreen {
            showMenu = false
        }

        if returnToQueue {
            navigateToQueue()
        }
    }

    func handleRequestReview(_ requestReview: @escaping () -> Void) {
        guard askForReviewCount < Const.askForReviewMaxCount else { return }
        askForReviewPoints += 1
        if askForReviewPoints >= Const.askForReviewPointThreshold {
            askForReviewPoints = -70
            askForReviewCount += 1
            requestReview()
        }
    }

    func handleVideoDetail(scrollToCurrentChapter: Bool = false) {
        self.scrollToCurrentChapter = scrollToCurrentChapter
        withAnimation {
            playerTab = .chapterDescription
        }
    }

    func toggleSidebar(show: Bool? = nil) {
        let shouldShow = show ?? isSidebarHidden
        columnVisibility = shouldShow ? .all : .detailOnly
    }

    var isSidebarHidden: Bool {
        columnVisibility == .detailOnly
    }

    static func getDummy(_ showMenu: Bool = true) -> NavigationManager {
        let navManager = NavigationManager()
        navManager.showMenu = showMenu
        // navManager.playerTab = .chapterDescription
        return navManager
    }
}

enum NavManagerCodingKeys: CodingKey {
    case showMenu,
         tab,
         askForReviewPoints,
         askForReviewCount,
         presentedLibrary,
         presentedInbox,
         presentedSubscriptionInbox,
         columnVisibility,
         queueTagId,
         queueTag
}

enum NavigationTab: String, Codable, CustomStringConvertible {
    case inbox
    case queue
    case library
    case browser
    case search

    var description: String {
        switch self {
        case .inbox:
            return String(localized: "inbox")
        case .queue:
            return String(localized: "queue")
        case .library:
            return String(localized: "library")
        case .browser:
            return String(localized: "browserShort")
        case .search:
            return String(localized: "search")
        }
    }

    var stringKey: LocalizedStringKey {
        switch self {
        case .inbox:
            return "inbox"
        case .queue:
            return "queue"
        case .library:
            return "library"
        case .browser:
            return "browserShort"
        case .search:
            return "search"
        }
    }
}

enum ControlNavigationTab: Int {
    case controls
    case chapterDescription
}
