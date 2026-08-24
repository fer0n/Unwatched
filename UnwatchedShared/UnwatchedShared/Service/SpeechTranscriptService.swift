//
//  SpeechTranscriptService.swift
//  UnwatchedShared
//

#if !os(tvOS)
import AVFoundation
import Foundation
import OSLog
import Speech

public enum SpeechTranscriptError: LocalizedError {
    case unsupportedDevice
    case unsupportedLanguage
    case emptyResult

    public var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            return String(localized: "transcriptionUnsupportedDevice")
        case .unsupportedLanguage:
            return String(localized: "transcriptionUnsupportedLanguage")
        case .emptyResult:
            return String(localized: "transcriptionEmpty")
        }
    }
}

/// Transcribes an audio file on device with `SpeechAnalyzer`, in the same shape the caption parsers produce — so a
/// generated transcript is a transcript like any other downstream.
public enum SpeechTranscriptService {
    /// False on devices whose hardware the speech models don't run on, which is what hides the feature rather than
    /// letting it fail at the end of a long transcription.
    public static var isSupported: Bool {
        SpeechTranscriber.isAvailable
    }

    /// - Parameters:
    ///   - language: the spoken language of the audio as the feed states it (e.g. "de", "en-US"). A model for
    ///     that language is what's used; the reader's own language only stands in when the feed says nothing.
    ///   - progress: fraction of the episode transcribed so far, on an arbitrary thread.
    public static func transcribe(
        fileUrl: URL,
        language: String? = nil,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [TranscriptEntry] {
        guard isSupported else {
            throw SpeechTranscriptError.unsupportedDevice
        }
        guard let locale = await transcriptionLocale(for: language) else {
            throw SpeechTranscriptError.unsupportedLanguage
        }
        Log.info("transcribing in \(locale.identifier) (feed language: \(language ?? "–"))")

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            // no volatile results: a file is transcribed once, and the tentative passes would only be thrown away
            // again
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )

        try await installModel(for: transcriber, locale: locale)

        let file = try AVAudioFile(forReading: fileUrl)
        let format = file.processingFormat
        let duration = format.sampleRate > 0 ? Double(file.length) / format.sampleRate : 0

        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // Results have to be consumed while the analyzer runs: the module publishes them as it goes, and
        // `analyzeSequence` doesn't return until the whole file has been read.
        let collector = Task {
            var entries = [TranscriptEntry]()
            for try await result in transcriber.results {
                let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }

                let range = result.range
                let start = range.start.seconds
                guard start.isFinite else { continue }
                let end = range.end.seconds
                entries.append(
                    TranscriptEntry(
                        start: start,
                        duration: end.isFinite ? max(0, end - start) : 0,
                        text: text
                    )
                )
                if duration > 0, end.isFinite {
                    progress(min(1, end / duration))
                }
            }
            return entries
        }

        do {
            let lastSampleTime = try await analyzer.analyzeSequence(from: file)
            if let lastSampleTime {
                try await analyzer.finalizeAndFinish(through: lastSampleTime)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            collector.cancel()
            await analyzer.cancelAndFinishNow()
            throw error
        }

        let entries = try await collector.value
        guard !entries.isEmpty else {
            throw SpeechTranscriptError.emptyResult
        }
        return entries
    }

    /// The model locale to transcribe in: the show's own language where there is a model for it, and the reader's
    /// language only for a feed that doesn't state one. A show whose language has no model is not transcribed at
    /// all — running German audio through an English model produces nonsense rather than a translation.
    private static func transcriptionLocale(for language: String?) async -> Locale? {
        if let language, let requested = locale(fromFeedLanguage: language) {
            return await SpeechTranscriber.supportedLocale(equivalentTo: requested)
        }
        return await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
    }

    /// Feeds write their language every which way — "de", "en-us", "pt_BR", "EN" — and `Locale` wants a BCP 47 tag.
    private static func locale(fromFeedLanguage language: String) -> Locale? {
        let identifier = language
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        guard !identifier.isEmpty, Locale.Language(identifier: identifier).languageCode != nil else {
            return nil
        }
        return Locale(identifier: identifier)
    }

    /// Installs the speech model. An app only gets so many locale reservations, and transcribing shows in a few
    /// languages runs into that limit — so a locale that's in the way is released and the install retried, rather
    /// than the transcription failing on a show the user just asked for.
    private static func installModel(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        do {
            try await requestInstall(transcriber, locale: locale)
        } catch {
            guard await releaseReservation(otherThan: locale) else { throw error }
            try await requestInstall(transcriber, locale: locale)
        }
    }

    private static func requestInstall(_ transcriber: SpeechTranscriber, locale: Locale) async throws {
        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            Log.info("downloading speech model for \(locale.identifier)")
            try await installation.downloadAndInstall()
        }
    }

    /// Gives up the reservation for one language the user isn't transcribing right now. The model stays on the
    /// device for a while, so a show they come back to usually doesn't download again.
    private static func releaseReservation(otherThan locale: Locale) async -> Bool {
        let reserved = await AssetInventory.reservedLocales
        guard let victim = reserved.first(where: { $0.identifier != locale.identifier }) else {
            return false
        }
        Log.info("releasing speech model reservation for \(victim.identifier)")
        return await AssetInventory.release(reservedLocale: victim)
    }
}
#endif
