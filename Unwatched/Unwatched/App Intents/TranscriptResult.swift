//
//  TranscriptResult.swift
//  Unwatched
//

import AppIntents

struct TranscriptResult: TransientAppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Transcript"

    @Property(title: "transcriptStatus")
    var status: TranscriptGenerationStatus

    @Property(title: "transcriptText")
    var text: String

    @Property(title: "retryAfterSeconds")
    var retryAfterSeconds: Int?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(stringLiteral: text)
    }

    init() {
        self.status = .ready
        self.text = ""
        self.retryAfterSeconds = nil
    }

    init(status: TranscriptGenerationStatus, text: String, retryAfterSeconds: Int?) {
        self.status = status
        self.text = text
        self.retryAfterSeconds = retryAfterSeconds
    }
}

enum TranscriptGenerationStatus: String, AppEnum {
    case ready
    case pending

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "transcriptStatus"
    static let caseDisplayRepresentations: [TranscriptGenerationStatus: DisplayRepresentation] = [
        .ready: "transcriptStatusReady",
        .pending: "transcriptStatusPending"
    ]
}
