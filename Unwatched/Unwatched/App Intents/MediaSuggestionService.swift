//
//  MediaSuggestionService.swift
//  Unwatched
//

#if os(iOS)
import Foundation
import Intents
import SwiftData
import UIKit
import UnwatchedShared

/// Tells the system what audio Unwatched could play, which is what gets the app's episodes offered in Control
/// Center's audio suggestions — and in Siri's, on the lock screen and in the Home app.
@MainActor
enum MediaSuggestionService {
    /// How far down the queue to offer.
    private static let suggestionCount = 5

    private static var lastDonatedId: String?

    /// The system only generates audio suggestions from media it doesn't consider video — `.movie`, `.tvShow`,
    /// `.tvShowEpisode`, `.musicVideo`, `.news` and `.unknown` are all left out of them.
    private static let itemType: INMediaItemType = .podcastEpisode

    static func setup() {
        // suggestions from what was played as well as from the queue
        INUpcomingMediaManager.shared.setPredictionMode(.default, for: itemType)
    }

    /// A tap in Control Center starts playback with no screen to draw into, which only the native player can do (see
    /// `BackgroundPlaybackManager`).
    static func isSuggestable(_ video: Video) -> Bool {
        video.isPodcast || PlayerTypeSetting.stored == .native || suggestVideos(for: video)
    }

    /// Whether a suggestion for this video may switch the player to the native one, which is what
    /// `Const.suggestVideos` allows — a tag of the video or of its channel can override it.
    static func suggestVideos(for video: Video) -> Bool {
        Tag.suggestVideosTag(for: video)?.suggestVideos
            ?? UserDefaults.standard.bool(forKey: Const.suggestVideos)
    }

    /// Call whenever a video starts playing; repeated calls for the same video are ignored, so pausing and resuming
    /// doesn't donate again.
    static func donate(_ video: Video) {
        guard isSuggestable(video), video.youtubeId != lastDonatedId else {
            return
        }
        lastDonatedId = video.youtubeId
        let youtubeId = video.youtubeId
        Task {
            let interaction = INInteraction(intent: await playIntent(for: video), response: nil)
            // keyed by the video, so `removeDonation` can take this one back once it's watched
            interaction.identifier = youtubeId
            do {
                try await interaction.donate()
                Log.info("mediaSuggestions: donated \(youtubeId)")
            } catch {
                Log.error("mediaSuggestions: donating \(youtubeId) failed — \(error.localizedDescription)")
            }
        }
    }

    /// Offers the top of the queue as what to play next.
    static func refreshSuggestions() {
        Task {
            let context = DataProvider.newContext()
            let videos = QueueFilter.all
                .videos(context, limit: suggestionCount)
                .filter(isSuggestable)
            var intents: [INPlayMediaIntent] = []
            for video in videos {
                intents.append(await playIntent(for: video))
            }
            INUpcomingMediaManager.shared.setSuggestedMediaIntents(NSOrderedSet(array: intents))
            Log.info("mediaSuggestions: suggested \(intents.count) videos")
        }
    }

    /// Watched or cleared: the system shouldn't keep offering it.
    static func removeDonation(for youtubeId: String) {
        if youtubeId == lastDonatedId {
            lastDonatedId = nil
        }
        INInteraction.delete(with: [youtubeId]) { error in
            if let error {
                Log.error("mediaSuggestions: deleting \(youtubeId) failed — \(error.localizedDescription)")
            }
        }
    }

    private static func playIntent(for video: Video) async -> INPlayMediaIntent {
        let episodeArtwork = await artwork(for: video.displayThumbnailUrl)
        let item = INMediaItem(
            identifier: video.youtubeId,
            title: video.title,
            type: itemType,
            artwork: episodeArtwork,
            artist: video.subscription?.author ?? video.subscription?.displayTitle
        )
        var show: INMediaItem?
        if let subscription = video.subscription, let key = subscription.subscriptionKey {
            // the show is what the Control Center row is titled after, so it needs a cover of its own
            let showArtwork = subscription.thumbnailUrl == video.displayThumbnailUrl
                ? episodeArtwork
                : await artwork(for: subscription.thumbnailUrl)
            show = INMediaItem(
                identifier: key,
                title: subscription.displayTitle,
                type: .podcastShow,
                artwork: showArtwork
            )
        }
        return INPlayMediaIntent(
            mediaItems: [item],
            mediaContainer: show,
            playShuffled: false,
            playbackRepeatMode: .none,
            // "resume" rather than "play" for anything already started
            resumePlayback: (video.elapsedSeconds ?? 0) > 0
        )
    }

    /// Artwork travels to another process inline, and the system drops what's too heavy to carry — podcast covers
    /// are routinely 3000×3000 — so it goes over downsampled and re-encoded rather than as the original bytes.
    private static let artworkPixelSize: CGFloat = 512

    private static func artwork(for url: URL?) async -> INImage? {
        guard let url,
              let data = await ImageService.imageData(for: url),
              let image = PlatformImage(downsampling: data, maxPixelSize: artworkPixelSize),
              let jpeg = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        return INImage(imageData: jpeg)
    }
}
#endif
