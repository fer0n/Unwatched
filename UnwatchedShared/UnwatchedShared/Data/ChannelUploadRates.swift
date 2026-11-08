//
//  ChannelUploadRates.swift
//  UnwatchedShared
//

import Foundation
import OSLog

public struct UploadRate: Sendable, Equatable {
    public var videosPerWeek: Double?
    public var shortsPerWeek: Double?
}

@MainActor
@Observable public final class ChannelUploadRates {
    public private(set) var rates = [String: UploadRate]()
    public private(set) var unavailable = Set<String>()
    @ObservationIgnored private var inFlight = [String: Task<UploadRate?, Never>]()
    @ObservationIgnored private var activeFetches = 0
    @ObservationIgnored private var slotWaiters = [CheckedContinuation<Void, Never>]()
    private static let maxConcurrentFetches = 6

    public init() {}

    public func load(channelId: String) async {
        guard rates[channelId] == nil else { return }
        if let fetch = inFlight[channelId] {
            _ = await fetch.value
            return
        }
        await acquireFetchSlot()
        defer { releaseFetchSlot() }
        guard !Task.isCancelled, rates[channelId] == nil else { return }
        if let fetch = inFlight[channelId] {
            _ = await fetch.value
            return
        }
        let fetch = Task { await Self.uploadRate(channelId: channelId) }
        inFlight[channelId] = fetch
        let rate = await fetch.value
        inFlight[channelId] = nil
        if let rate {
            rates[channelId] = rate
            unavailable.remove(channelId)
        } else {
            unavailable.insert(channelId)
        }
    }

    public func load(channelIds: [String]) async {
        await withTaskGroup { group in
            for channelId in channelIds where rates[channelId] == nil {
                group.addTask { await self.load(channelId: channelId) }
            }
        }
    }

    private func acquireFetchSlot() async {
        guard activeFetches >= Self.maxConcurrentFetches else {
            activeFetches += 1
            return
        }
        await withCheckedContinuation { slotWaiters.append($0) }
    }

    private func releaseFetchSlot() {
        if slotWaiters.isEmpty {
            activeFetches -= 1
        } else {
            slotWaiters.removeFirst().resume()
        }
    }

    public func hasLoaded(channelIds: [String]) -> Bool {
        channelIds.allSatisfy { rates[$0] != nil || unavailable.contains($0) }
    }

    public func total(channelIds: [String]) -> UploadRate {
        let known = channelIds.compactMap { rates[$0] }
        func sum(_ value: KeyPath<UploadRate, Double?>) -> Double? {
            let values = known.compactMap { $0[keyPath: value] }
            return values.isEmpty ? nil : values.reduce(0, +)
        }
        return UploadRate(videosPerWeek: sum(\.videosPerWeek), shortsPerWeek: sum(\.shortsPerWeek))
    }

    private nonisolated static let feedLength = 15
    private nonisolated static let minSamples = 3

    nonisolated static func uploadRate(channelId: String, now: Date = .now) async -> UploadRate? {
        guard let uploads = await fetchUploads(feedQuery: "channel_id=\(channelId)"), !uploads.isEmpty else { return nil }
        let videos = uploads.filter { !$0.isShort }.map(\.date)
        let shorts = uploads.filter(\.isShort).map(\.date)
        let since = uploads.map(\.date).min()
        var rate = UploadRate(
            videosPerWeek: perWeek(videos.count, since: since, now: now),
            shortsPerWeek: perWeek(shorts.count, since: since, now: now)
        )
        guard uploads.count >= feedLength, channelId.hasPrefix("UC") else { return rate }
        let playlistId = channelId.dropFirst(2)
        if videos.count < minSamples, let longForm = await fetchUploads(feedQuery: "playlist_id=UULF\(playlistId)") {
            rate.videosPerWeek = perWeek(longForm.count, since: longForm.map(\.date).min(), now: now)
        } else if shorts.count < minSamples, let onlyShorts = await fetchUploads(feedQuery: "playlist_id=UUSH\(playlistId)") {
            rate.shortsPerWeek = perWeek(onlyShorts.count, since: onlyShorts.map(\.date).min(), now: now)
        }
        return rate
    }

    nonisolated static func perWeek(_ count: Int, since oldest: Date?, now: Date) -> Double? {
        guard count > 0, let oldest else { return nil }
        let day: TimeInterval = 24 * 60 * 60
        return Double(count) / (max(now.timeIntervalSince(oldest), day) / (7 * day))
    }

    private nonisolated static func fetchUploads(feedQuery: String) async -> [(date: Date, isShort: Bool)]? {
        guard let url = URL(string: "https://www.youtube.com/feeds/videos.xml?\(feedQuery)") else { return nil }
        do {
            return try await VideoCrawler.loadVideosFromRSS(url: url).compactMap { video in
                video.publishedDate.map { ($0, video.isYtShort == true) }
            }
        } catch {
            Log.info("upload rate feed \(feedQuery) failed: \(error)")
            return nil
        }
    }
}
