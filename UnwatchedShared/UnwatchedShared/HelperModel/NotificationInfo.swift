//
//  NotificationInfo.swift
//  UnwatchedShared
//

public struct NotificationInfo: Sendable {
    public let title: String
    public let subtitle: String

    public let categoryIdentifier: String?
    public var video: SendableVideo?

    public init(
        _ title: String,
        _ subtitle: String,
        video: SendableVideo? = nil,
        placement: VideoPlacementArea? = nil,
        enableActions: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle

        self.video = video

        var categoryIdentifier: String?
        if enableActions {
            // find out if the video is in the inbox or queue
            categoryIdentifier = placement == .queue
                ? Const.queueVideoAddedCategory
                : placement == .inbox
                ? Const.inboxVideoAddedCategory
                : nil
        }
        self.categoryIdentifier = categoryIdentifier
    }
}
