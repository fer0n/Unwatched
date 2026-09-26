//
//  NavigationManager+Routes.swift
//  Unwatched
//

import OSLog
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

    func pushVideoDetail(_ video: Video) {
        let route = VideoDetailRoute(video)
        push(.video(route), inSearch: .video(route)) {
            presentedLibrary.append(route)
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

    func pushToLibrary(_ sendableSub: SendableSubscription) {
        if lastLibrarySubscriptionId != sendableSub.persistentId {
            presentedLibrary.append(sendableSub)
            lastLibrarySubscriptionId = sendableSub.persistentId
        }
    }
}
