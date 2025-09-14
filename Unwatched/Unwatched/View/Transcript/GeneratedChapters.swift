//
//  GeneratedChapters.swift
//  Unwatched
//

import FoundationModels
import UnwatchedShared

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct ChapterGeneration {
    var chapters: [GeneratedChapter]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "A video chapter")
struct GeneratedChapter: CustomStringConvertible, Hashable {

    @Guide(description: "Short and concise chapter title")
    public var title: String

    @Guide(description: "Start time in seconds")
    public var startTime: Double

    var description: String {
        return "\(title) (\(startTime))"
    }

    var toSendableChapter: SendableChapter {
        return SendableChapter(title: title, startTime: startTime)
    }
}
