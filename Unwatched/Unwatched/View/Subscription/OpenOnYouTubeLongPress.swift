//
//  OpenOnYouTubeLongPress.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct OpenOnYouTubeLongPress: ViewModifier {
    @Environment(NavigationManager.self) var navManager
    @AppStorage(Const.browserDisplayMode) var browserDisplayMode: BrowserDisplayMode = .inApp
    @State var triggerFeedback = false
    @State var triggerErrorFeedback = false

    let subscription: Subscription

    func body(content: Content) -> some View {
        if browserDisplayMode == .disabled {
            content
        } else {
            content
                .contentShape(.rect)
                .onLongPressGesture(minimumDuration: 0.3) {
                    if let url = subscription.youtubeUrl() {
                        triggerFeedback.toggle()
                        navManager.openUrlInApp(.url(url))
                    } else {
                        triggerErrorFeedback.toggle()
                    }
                }
                .sensoryFeedback(Const.sensoryFeedback, trigger: triggerFeedback)
                .sensoryFeedback(.error, trigger: triggerErrorFeedback)
                .accessibilityAction(named: "browser") {
                    if let url = subscription.youtubeUrl() {
                        navManager.openUrlInApp(.url(url))
                    }
                }
        }
    }
}

extension Subscription {
    func youtubeUrl(mobile: Bool = true) -> String? {
        UrlService.getYoutubeUrl(
            userName: youtubeUserName,
            channelId: youtubeChannelId,
            playlistId: youtubePlaylistId,
            mobile: mobile
        )
    }
}
