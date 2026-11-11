//
//  NavigationManager+Routes.swift
//  Unwatched
//

import OSLog
import SwiftUI
import UnwatchedShared

extension NavigationManager {
    func pushSubscription(
        subscription: Subscription? = nil,
        sendableSubscription: SendableSubscription? = nil
    ) {
        guard let sendableSub = sendableSubscription ?? subscription?.toExport else {
            Log.error("pushSubscription: no subscription given")
            return
        }
        push(.subscription(sendableSub), inSearch: .subscription(sendableSub)) {
            pushToLibrary(sendableSub)
        }
    }

    func pushChannel(of video: Video) {
        if let channel = video.channelSubscription {
            pushSubscription(subscription: channel)
        } else if let channelId = video.uploaderChannelId {
            pushSubscription(sendableSubscription: SendableSubscription(
                title: video.channelTitle ?? "",
                youtubeChannelId: channelId
            ))
        } else {
            pushSubscription(subscription: video.subscription)
        }
    }

    func pushVideoDetail(_ video: Video) {
        let route = VideoDetailRoute(video)
        push(.video(route), inSearch: .video(route)) {
            presentedLibrary.append(route)
        }
    }

    /// Falls back to opening the link
    func openVideoDetail(for url: URL) {
        openLink(url) {
            guard let video = try await VideoService.importFirst(url, in: nil) else { return nil }
            return { self.pushVideoDetail(video) }
        }
    }

    func openSubscriptionDetail(for url: URL) {
        openLink(url) {
            let sub = try await SubscriptionService.resolveSubscription(url)
            return { self.pushSubscription(sendableSubscription: sub) }
        }
    }

    private func openLink(_ url: URL, resolve: @escaping @MainActor () async throws -> (() -> Void)?) {
        linkTask?.cancel()
        linkTask = Task { @MainActor in
            do {
                if let push = try await resolve() {
                    try Task.checkCancellation()
                    showBrowser = false
                    // an animated push renders at the pre-rise sheet height
                    var transaction = Transaction()
                    transaction.disablesAnimations = !showMenu || SheetPositionReader.shared.isMinimumSheet
                    withTransaction(transaction, push)
                    revealMenu()
                    return
                }
            } catch is CancellationError {
                return
            } catch {
                Log.sync.error("openLink: \(error)")
            }
            guard !Task.isCancelled else { return }
            UrlService.open(ShareMarkers.removing(from: url))
        }
    }

    func replaceInboxVideoDetail(with video: Video) {
        popVideo(from: &presentedInbox)
        presentedInbox.append(.video(VideoDetailRoute(video)))
    }

    func popVideoDetail() {
        switch tab {
        case .inbox:
            popVideo(from: &presentedInbox)
        case .queue:
            popVideo(from: &presentedQueue)
        case .search:
            if case .video = presentedSearch.last {
                presentedSearch.removeLast()
            }
        case .library:
            if !presentedLibrary.isEmpty {
                presentedLibrary.removeLast()
            }
        case .browser:
            break
        }
    }

    var canPopCurrentTab: Bool {
        switch tab {
        case .inbox: !presentedInbox.isEmpty
        case .queue: !presentedQueue.isEmpty
        case .library: !presentedLibrary.isEmpty
        case .search: !presentedSearch.isEmpty
        case .browser: false
        }
    }

    func popCurrentTab() {
        guard canPopCurrentTab else { return }
        switch tab {
        case .inbox: presentedInbox.removeLast()
        case .queue: presentedQueue.removeLast()
        case .library: presentedLibrary.removeLast()
        case .search: presentedSearch.removeLast()
        case .browser: break
        }
    }

    private func popVideo(from path: inout [MenuRoute]) {
        if case .video = path.last {
            path.removeLast()
        }
    }

    private func push(_ route: MenuRoute, inSearch searchRoute: SearchRoute, inLibrary pushLibrary: () -> Void) {
        switch tab {
        case .inbox:
            push(route, onto: &presentedInbox)
        case .queue:
            push(route, onto: &presentedQueue)
        case .search:
            push(searchRoute, onto: &presentedSearch)
        case .browser:
            tab = .library
            pushLibrary()
        case .library:
            pushLibrary()
        }
    }

    private func push<Route: Equatable>(_ route: Route, onto path: inout [Route]) {
        if path.last != route {
            path.append(route)
        }
    }

    #if os(macOS)
    func openChapterSettings(_ openSettings: OpenSettingsAction) {
        settingsWindowTab = .chapters
        openSettings()
    }
    #else
    func openSettings(_ page: LibraryDestination) {
        clearNavigationStack(.library)
        presentedLibrary.append(LibraryDestination.settings)
        presentedLibrary.append(page)
        navigateTo(.library)
    }
    #endif

    func pushToLibrary(_ sendableSub: SendableSubscription) {
        // a preview has no id, which matched the nil of an empty stack
        if sendableSub.persistentId == nil || lastLibrarySubscriptionId != sendableSub.persistentId {
            presentedLibrary.append(sendableSub)
            lastLibrarySubscriptionId = sendableSub.persistentId
        }
    }
}

struct OpenChapterSettingsAction: DynamicProperty {
    @Environment(NavigationManager.self) private var navManager
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    @MainActor
    func callAsFunction() {
        #if os(macOS)
        navManager.openChapterSettings(openSettings)
        #else
        navManager.openSettings(.settingsChapters)
        #endif
    }
}
