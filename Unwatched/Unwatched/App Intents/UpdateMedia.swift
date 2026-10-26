//
//  UpdateMedia.swift
//  Unwatched
//

import AppIntents
import SwiftData
import UnwatchedShared

/// Every field is optional: an empty one leaves that part of the media alone.
struct UpdateMedia: AppIntent {
    static var title: LocalizedStringResource { "updateMedia" }
    static let description = IntentDescription("updateMediaDescription")
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "updateMediaMedia", description: "updateMediaMediaDescription")
    var media: VideoEntity?

    @Parameter(title: "playbackPosition", description: "playbackPositionDescription")
    var position: Double?

    @Parameter(title: "watched", default: .unchanged)
    var watched: FlagChange

    @Parameter(title: "bookmarked", default: .unchanged)
    var bookmarked: FlagChange

    @Parameter(title: "markedAsNew", default: .unchanged)
    var isNew: FlagChange

    @Parameter(title: "addTags")
    var addTags: [TagEntity]?

    @Parameter(title: "removeTags")
    var removeTags: [TagEntity]?

    @Parameter(title: "moveTo")
    var moveTo: MediaPlacement?

    @Parameter(title: "queuePosition", description: "queuePositionDescription", default: 1)
    var queuePosition: Int

    @Parameter(title: "playTag", description: "queuePositionTagDescription")
    var queueTag: TagEntity?

    static var parameterSummary: some ParameterSummary {
        When(\.$moveTo, .equalTo, .queuePosition) {
            Summary("updateMedia \(\.$media)") {
                \.$position
                \.$watched
                \.$bookmarked
                \.$isNew
                \.$addTags
                \.$removeTags
                \.$moveTo
                \.$queuePosition
                \.$queueTag
            }
        } otherwise: {
            Summary("updateMedia \(\.$media)") {
                \.$position
                \.$watched
                \.$bookmarked
                \.$isNew
                \.$addTags
                \.$removeTags
                \.$moveTo
            }
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<VideoEntity> {
        Signal.log("Shortcut.UpdateMedia")
        let video = try resolveVideo()
        let context = video.modelContext ?? DataProvider.mainContext
        let player = PlayerManager.shared
        let topBefore = player.topVideoInQueue(context)?.youtubeId

        // State first, then placement: marking a video watched clears it from the Queue, and
        // leaving the Queue resets `isNew`, so either would undo a placement or flag set before it.
        if let position {
            setPosition(position, of: video)
        }
        if let watched = watched.value {
            VideoService.setVideoWatched(video, watched: watched, modelContext: context)
        }
        if let bookmarked = bookmarked.value, (video.bookmarkedDate != nil) != bookmarked {
            VideoService.toggleBookmark(video)
        }
        try updateTags(of: video)
        if let moveTo {
            try place(video, moveTo, context)
        }
        if let isNew = isNew.value {
            VideoService.forceUpdateVideoNow(video.persistentModelID, isNew: isNew)
        }
        try context.save()

        // Matches the Queue's own moves: a new top replaces what the player has loaded
        if player.topVideoInQueue(context)?.youtubeId != topBefore {
            player.loadTopmostVideoFromQueue(modelContext: context)
        }
        return .result(value: VideoEntity(video))
    }

    @MainActor
    private func resolveVideo() throws -> Video {
        guard let media else {
            return try VideoService.getVideoOrCurrent(nil)
        }
        guard let video = VideoService.getVideo(for: media.id, modelContext: DataProvider.mainContext) else {
            throw VideoError.noVideoFound
        }
        return video
    }

    /// The loaded video goes through the player, which would otherwise save its own time over this one.
    @MainActor
    private func setPosition(_ position: Double, of video: Video) {
        let seconds = max(0, position)
        let player = PlayerManager.shared
        if player.video?.youtubeId == video.youtubeId {
            player.seek(to: seconds)
            player.updateElapsedTime(seconds, videoId: video.youtubeId, immediate: true)
        } else {
            VideoService.forceUpdateVideoNow(video.persistentModelID, elapsedSeconds: seconds)
        }
    }

    @MainActor
    private func updateTags(of video: Video) throws {
        for entity in addTags ?? [] {
            try Self.tag(entity).setCovers(video: video, true)
        }
        for entity in removeTags ?? [] {
            try Self.tag(entity).setCovers(video: video, false)
        }
    }

    @MainActor
    private static func tag(_ entity: TagEntity) throws -> Tag {
        guard let tag = TagEntityQuery.tag(named: entity.name) else {
            throw BackgroundPlaybackError.tagNotFound
        }
        return tag
    }

    @MainActor
    private func place(_ video: Video, _ placement: MediaPlacement, _ context: ModelContext) throws {
        switch placement {
        case .queueNext:
            VideoService.insertQueueEntries(at: 1, videos: [video], modelContext: context)
        case .queueLast:
            VideoService.addToBottomQueue(video: video, modelContext: context)
        case .queuePosition:
            let filter = QueueFilter(try queueTag?.selection() ?? .all, context)
            let index = Self.queueIndex(for: queuePosition, excluding: video, in: filter, context)
            VideoService.insertQueueEntries(at: index, videos: [video], filter: filter, modelContext: context)
        case .inbox:
            VideoService.moveVideoToInbox(video, modelContext: context)
        case .clear:
            VideoService.clearEntries(from: video, modelContext: context)
        }
    }

    /// From a 1-based position, negative counting from the end, to the index `insertQueueEntries` takes.
    /// Out-of-range positions land at the top or bottom.
    @MainActor
    private static func queueIndex(
        for position: Int,
        excluding video: Video,
        in filter: QueueFilter,
        _ context: ModelContext
    ) -> Int {
        if position >= 1 {
            return position - 1
        }
        if position >= -1 {
            return position == 0 ? 0 : -1
        }
        let others = filter.entries(context).count { $0.video?.youtubeId != video.youtubeId }
        return max(0, others + position + 1)
    }
}

/// A Bool parameter has no "leave it alone" state in Shortcuts: an untouched switch reads as off.
enum FlagChange: String, AppEnum {
    case unchanged
    case enabled
    case disabled

    var value: Bool? {
        switch self {
        case .unchanged: nil
        case .enabled: true
        case .disabled: false
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "flagChangeType" }

    static var caseDisplayRepresentations: [FlagChange: DisplayRepresentation] {
        [
            .unchanged: "flagUnchanged",
            .enabled: "flagYes",
            .disabled: "flagNo"
        ]
    }
}

enum MediaPlacement: String, AppEnum {
    case queueNext
    case queueLast
    case queuePosition
    case inbox
    case clear

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "mediaPlacementType" }

    static var caseDisplayRepresentations: [MediaPlacement: DisplayRepresentation] {
        [
            .queueNext: "queueNext",
            .queueLast: "queueLast",
            .queuePosition: "queuePosition",
            .inbox: "inbox",
            .clear: "clear"
        ]
    }
}
