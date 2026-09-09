//
//  GapChapterService.swift
//  Unwatched
//

import FoundationModels
import SwiftUI
import UnwatchedShared

@Generable(description: "What a stretch of podcast audio contains")
struct GapLabel {
    @Generable
    enum Kind {
        /// A paid advertisement or sponsor read for someone other than the show.
        case advertisement
        /// The show promoting itself: its own membership, merchandise, live dates or other shows.
        case selfPromotion
        /// Part of the episode, a trailer for an unrelated show, a station ident, anything else.
        case notPromotional
    }

    @Guide(description: "How this stretch is best categorised")
    var kind: Kind

    @Guide(description: """
    The brand, product or company being promoted — or, when it is not a promotion, what it is about. \
    At most four words. Never include a category name or brackets.
    """)
    var title: String
}

/// Turns the spans a show's own transcript doesn't cover into chapters.
///
/// The spans are measured; what's in them is not, so nothing is categorised until the audio has
/// been transcribed and read. The category is what the chapter list renders the `[Sponsor]` prefix
/// from and what SponsorBlock's skip settings act on, so the title stays the bare name.
struct GapChapterService {
    /// Shorter than this and a chapter is noise in the list.
    private static let minimumGapForChapter: Double = 10

    @MainActor
    @discardableResult
    static func insertGapChapters(
        for video: Video,
        alignment: TranscriptAlignment,
        transcript: [TranscriptEntry]
    ) async -> Bool {
        let gaps = alignment.gaps.filter { $0.duration >= minimumGapForChapter }
        guard !gaps.isEmpty else { return false }
        let show = video.subscription?.displayTitle

        var segments = [SendableChapter]()
        for gap in gaps {
            let labelled = await label(forSpokenTextIn: gap, of: transcript, show: show)
            segments.append(
                SendableChapter(
                    title: labelled.title,
                    startTime: gap.audioStart,
                    endTime: gap.audioEnd,
                    category: labelled.category
                )
            )
        }
        Log.info("insertGapChapters: \(segments)")
        return withAnimation {
            ChapterService.mergeSegments(segments, into: video)
        }
    }

    private static func label(
        forSpokenTextIn gap: TranscriptAlignment.Gap,
        of transcript: [TranscriptEntry],
        show: String?
    ) async -> (title: String?, category: ChapterCategory) {
        let text = transcript
            .filter { $0.start >= gap.audioStart - 1 && $0.start < gap.audioEnd }
            .map(\.text)
            .joined(separator: " ")
        return await label(for: text, show: show)
    }

    /// Reads the transcribed span and categorises it. Without text, without a model, or on a
    /// failure it stays an untitled `.notTranscribed` chapter, which says only what was measured.
    ///
    /// The model is trained to obey instructions over prompts, so the instructions carry nothing
    /// but our own words; the show's name comes from its feed and goes in the prompt, where it is
    /// read as data. It is there so a read for the show itself can be told from a paid one, which
    /// the words alone often can't settle.
    private static func label(
        for text: String,
        show: String?
    ) async -> (title: String?, category: ChapterCategory) {
        let unlabelled: (String?, ChapterCategory) = (nil, .notTranscribed)
        guard text.count > 40, SystemLanguageModel.default.availability == .available else {
            return unlabelled
        }

        let instructions = """
        Categorise one stretch of a podcast episode that the show's own transcript does not cover, \
        and name what it is about.

        It is usually an advertisement read into the episode on behalf of another company. It can \
        instead be the show promoting itself, part of the episode, a trailer for an unrelated show, \
        or a station ident. A promotion for the show named in the prompt — its membership, \
        merchandise, live dates or back catalogue — is self promotion rather than an advertisement.

        A discount code or a landing page for another company is an advertisement. An appeal to \
        support the show named in the prompt is self promotion.

        Judge only from the words in the prompt. DO NOT name a brand those words do not mention.
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt(for: text, show: show),
                                                     generating: GapLabel.self)
            return resolve(response.content)
        } catch {
            Log.info("gap label failed: \(error.localizedDescription)")
            return unlabelled
        }
    }

    private static func prompt(for text: String, show: String?) -> String {
        guard let show = show?.trimmingCharacters(in: .whitespacesAndNewlines), !show.isEmpty else {
            return """
            # What is said
            \(text)
            """
        }
        return """
        # The show this episode belongs to
        '\(show)'

        # What is said
        \(text)
        """
    }

    /// A model told not to name a category still does now and then, and the chapter list adds its
    /// own prefix — so the same parser that reads `sponsor: Squarespace` out of a description
    /// strips it back off here, and its verdict stands in when the model didn't give one.
    static func resolve(_ label: GapLabel) -> (title: String?, category: ChapterCategory) {
        let (parsed, stripped) = ChapterService.splitCategory(from: label.title)
        let title = stripped?.trimmingCharacters(in: .whitespacesAndNewlines)

        let category: ChapterCategory
        switch label.kind {
        case .advertisement: category = .sponsor
        case .selfPromotion: category = .selfpromo
        case .notPromotional: category = parsed == .chapter ? .notTranscribed : parsed
        }

        guard let title, !title.isEmpty else { return (nil, category) }
        return (title, category)
    }
}
