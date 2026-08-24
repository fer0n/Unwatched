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

    /// - Parameter progress: fraction of the episode transcribed so far, on an arbitrary thread.
    public static func transcribe(
        fileUrl: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [TranscriptEntry] {
        guard isSupported else {
            throw SpeechTranscriptError.unsupportedDevice
        }
        // The episode's own language isn't in the feed in any dependable form, so this transcribes
        // in the reader's language — which is the one whose model is most likely installed, and
        // the one they'd want a translation-free transcript in anyway.
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
            throw SpeechTranscriptError.unsupportedLanguage
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            // no volatile results: a file is transcribed once, and the tentative passes would only be thrown away
            // again
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )

        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            Log.info("downloading speech model for \(locale.identifier)")
            try await installation.downloadAndInstall()
        }

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
}
#endif
