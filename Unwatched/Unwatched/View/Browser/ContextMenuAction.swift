import UnwatchedShared

/// Shared struct to hold context menu information across platforms
struct ContextMenuAction {
    enum ActionType {
        case openInBrowser
        case copyUrl
        case subscribe
        case queueNext
        case addToInbox
    }

    /// Defines the group this action belongs to - used for determining separator placement
    enum ActionGroup: Int {
        case basic = 0
        case channel = 1
        case video = 2
    }

    let type: ActionType
    let title: String
    let imageName: String
    let group: ActionGroup

    static func getActionsForUrl(_ url: URL, info: SubscriptionInfo) -> [ContextMenuAction] {
        var actions: [ContextMenuAction] = [
            .init(
                type: .openInBrowser,
                title: String(localized: "openInExternalBrowser"),
                imageName: "safari.fill",
                group: .basic
            ),
            .init(
                type: .copyUrl,
                title: String(localized: "copyUrl"),
                imageName: Const.copySF,
                group: .basic
            )
        ]

        // Channel URL actions
        if info.channelId != nil || info.userName != nil || info.playlistId != nil {
            actions.append(
                .init(
                    type: .subscribe,
                    title: String(localized: "subscribe"),
                    imageName: "person.fill.badge.plus",
                    group: .channel
                )
            )
        }

        // Video URL actions
        if UrlService.getYoutubeIdFromUrl(url: url) != nil {
            actions.append(
                .init(
                    type: .queueNext,
                    title: String(localized: "queueNext"),
                    imageName: Const.queueTopSF,
                    group: .video
                )
            )
            actions.append(
                .init(
                    type: .addToInbox,
                    title: String(localized: "addToInbox"),
                    imageName: "tray.fill",
                    group: .video
                )
            )
        }
        return actions
    }
}
