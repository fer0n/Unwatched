//
//  HomeFeedService+Subscriptions.swift
//  UnwatchedShared
//

#if canImport(WebKit)
import Foundation

extension HomeFeedService {
    private static let subscriptionPageLimit = 100

    /// The "All subscriptions" page (`FEchannels`)
    public func fetchSubscribedChannels() async throws -> [SendableSubscription] {
        defer { scheduleRelease() }
        try await ensurePage()
        guard try await isLoggedIn() else { throw HomeFeedError.signedOut }

        var channels = [String: SendableSubscription]()
        var payload: [String: Any] = ["browseId": "FEchannels"]
        for _ in 0..<Self.subscriptionPageLimit {
            try Task.checkCancellation()
            let page: SubscribedChannelsParser.Page
            do {
                let body = try await rawRequest("browse", payload, pruneLockups: false)
                page = try await Task.detached(priority: .userInitiated) {
                    try SubscribedChannelsParser.parse(body)
                }.value
            } catch where !channels.isEmpty && !(error is CancellationError) {
                Log.innerTube.error("subscribed channels: next page failed, keeping \(channels.count): \(error)")
                break
            }
            let countBefore = channels.count
            for channel in page.channels {
                guard let id = channel.youtubeChannelId else { continue }
                channels[id] = channels[id] ?? channel
            }
            // a page without anything new would loop on the same token
            guard let token = page.nextPageToken, channels.count > countBefore else { break }
            payload = ["continuation": token]
        }
        Log.innerTube.info("subscribed channels: \(channels.count)")
        return channels.values.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}
#endif
