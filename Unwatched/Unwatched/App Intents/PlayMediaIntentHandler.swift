//
//  PlayMediaIntentHandler.swift
//  Unwatched
//

#if os(iOS)
import Foundation
import Intents
import SwiftData
import UnwatchedShared

/// Plays back what `MediaSuggestionService` handed the system: a tap on an audio suggestion in Control Center, on the
/// lock screen or in the Home app arrives here, as does "play X in Unwatched" from Siri.
final class PlayMediaIntentHandler: NSObject, INPlayMediaIntentHandling {
    func handle(intent: INPlayMediaIntent) async -> INPlayMediaIntentResponse {
        let item = intent.mediaItems?.first
        Log.info("""
            playMediaIntent: item \(item?.identifier ?? "nil") "\(item?.title ?? "")", \
            container \(intent.mediaContainer?.identifier ?? "nil"), \
            search \(intent.mediaSearch?.mediaName ?? "nil")
            """)
        do {
            try await start(intent)
            Signal.playbackStarted("mediaSuggestion")
            return INPlayMediaIntentResponse(code: .success, userActivity: nil)
        } catch BackgroundPlaybackError.nativePlayerRequired {
            // The web player is a WKWebView and needs a screen, so this one can't be played from the background.
            Log.info("playMediaIntent: needs the app in the foreground")
            return INPlayMediaIntentResponse(code: .continueInApp, userActivity: nil)
        } catch {
            Log.error("playMediaIntent: \(error.localizedDescription)")
            return INPlayMediaIntentResponse(code: .failure, userActivity: nil)
        }
    }

    @MainActor
    private func start(_ intent: INPlayMediaIntent) async throws {
        let video = video(for: intent)
        Log.info("playMediaIntent: playing \(video?.youtubeId ?? "the top of the queue")")
        // only what was offered on that basis in the first place, see `isSuggestable`
        let forceNativePlayer = video.map(MediaSuggestionService.canForceNativePlayer(for:)) ?? false
        try await BackgroundPlaybackManager.shared.start(
            forceNativePlayer: forceNativePlayer,
            video: video
        )
    }

    /// What the tap named. Unknown or deleted media falls back to the show it came from, and a show with nothing
    /// queued to the top of the queue, which is what the app plays when it's opened with nothing playing.
    @MainActor
    private func video(for intent: INPlayMediaIntent) -> Video? {
        let context = DataProvider.mainContext
        if let identifier = intent.mediaItems?.first?.identifier,
           let video = VideoService.getVideo(for: identifier, modelContext: context) {
            return video
        }
        guard let key = intent.mediaContainer?.identifier else {
            return nil
        }
        return topOfQueue(subscriptionKey: key, context)
    }

    /// `subscriptionKey` is computed, so the match can't be a predicate — there are few enough subscriptions for
    /// that not to matter.
    @MainActor
    private func topOfQueue(subscriptionKey: String, _ context: ModelContext) -> Video? {
        let subscriptions = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        guard let subscription = subscriptions.first(where: { $0.subscriptionKey == subscriptionKey }) else {
            return nil
        }
        let filter = QueueFilter(subscriptionIds: [subscription.persistentModelID])
        return filter.videos(context, limit: 1).first
    }
}
#endif
