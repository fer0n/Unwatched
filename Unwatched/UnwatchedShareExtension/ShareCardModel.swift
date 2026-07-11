//
//  ShareCardModel.swift
//  UnwatchedShareExtension
//

import Foundation
import UnwatchedShared

@Observable
final class ShareCardModel {
    enum State: Equatable {
        case choosing(ShareLinkKind)
        case working(String)
        case done(String)
        case error(String)
        case noLink
        case notYouTube

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.choosing, .choosing), (.working, .working), (.done, .done), (.error, .error),
                 (.noLink, .noLink), (.notYouTube, .notYouTube):
                return true
            default:
                return false
            }
        }
    }

    var state: State = .working(String(localized: "Loading…"))
    /// Non-nil only once we know the shared link points at a specific video (not a playlist).
    /// Starts as a bare placeholder (empty title, no thumbnail) and gets replaced once the
    /// metadata fetch completes — the same `VideoData`-based views the main app uses for its
    /// video lists render either state, showing their own placeholder while `thumbnailUrl` is nil.
    var videoPreview: SendableVideo?
    /// Non-nil while an action button's tap is being performed — the choosing view stays exactly
    /// as-is, with only that button's icon swapped for a spinner and all buttons disabled.
    var loadingAction: ShareAction?
    /// Non-nil the very first time ever the user picks an action, while we wait for them to
    /// answer whether that action should be remembered and auto-performed from now on.
    var pendingRememberPrompt: ShareAction?
    /// The shared channel/playlist's real name, thumbnail, and subscribed status — nil until the
    /// lookup (existing subscription, or a best-effort RSS fetch) completes.
    var channelPreview: SendableSubscription?
    var isSubscribed = false
    var isTogglingSubscription = false
}
