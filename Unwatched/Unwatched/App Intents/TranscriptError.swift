//
//  TranscriptError.swift
//  Unwatched
//

import Foundation

enum TranscriptError: Error, CustomLocalizedStringResourceConvertible, LocalizedError {
    case notFound
    case noUrl
    case noPublishedTranscript
    case emptyTranscript
    case noAudio
    case unsupportedDevice
    case cannotContinueInForeground
    case generationFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notFound:
            return "noTranscriptFound"
        case .noUrl:
            return "noTranscriptUrl"
        case .noPublishedTranscript:
            return "noPublishedTranscript"
        case .emptyTranscript:
            return "emptyTranscript"
        case .noAudio:
            return "noEpisodeAudio"
        case .unsupportedDevice:
            return "transcriptionUnsupportedDevice"
        case .cannotContinueInForeground:
            return "transcriptGenerationNeedsForeground"
        case .generationFailed(let message):
            return LocalizedStringResource(stringLiteral: message)
        }
    }

    var errorDescription: String? {
        return String(localized: localizedStringResource)
    }
}
