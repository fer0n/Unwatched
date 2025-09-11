//
//  GenerationService.swift
//  Unwatched
//

import FoundationModels
import UnwatchedShared
import Playgrounds

@available(iOS 26.0, macOS 26.0, *)
struct GenerationService {
    static let characterLimit = 8000 // 4096 token limit * roughly 4 characters per token

    public static func getUsableChunks(_ transcript: [TranscriptEntry]) -> [[TranscriptEntry]] {
        var chunks: [[TranscriptEntry]] = []
        var currentChunk: [TranscriptEntry] = []
        var currentLength = 0

        for entry in transcript {
            let entryLength = entry.text.count
            if currentLength + entryLength > characterLimit {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                currentChunk = [entry]
                currentLength = entryLength
            } else {
                currentChunk.append(entry)
                currentLength += entryLength
            }
        }
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }

    public static func extractChaptersFromTranscripts(
        _ videoTitle: String,
        _ transcript: [TranscriptEntry]
    ) async throws -> [SendableChapter]? {
        let usableChunks = getUsableChunks(transcript)
        Log.info("usableChunks \(usableChunks)")
        if usableChunks.isEmpty {
            return nil
        }
        var chapters: [GeneratedChapter] = []

        var isFirstChunk = true
        for chunk in usableChunks {
            let transcriptRepresentation = chunk.map(\.minimalTextRepresentation).joined(separator: "\n")
            Log.info("chunk \(transcriptRepresentation)")
            // swiftlint:disable all
            var instructions = """
            You are a video content analyzer specializing in creating chapter breakdowns from transcripts. Your job is to identify natural content segments and create meaningful chapter divisions that help viewers navigate video content efficiently.

            ## Primary Task
            Analyze the provided video transcript and generate a chapter structure by identifying distinct topics, themes, or content shifts. Create chapter titles and timestamps that accurately reflect the content flow and major discussion points.

            ## Processing Guidelines
            - Read through the entire transcript to understand the overall content flow
            - Identify natural breaking points where topics change or new themes are introduced
            - Pay attention to transition phrases that often signal a new section
            - Avoid chapters that are too short
            - Create descriptive but concise chapter titles that clearly indicate what content is covered

            ## Style Preferences
            - Keep chapter titles concise but informative (1-3 words typically)
            - Ensure titles are scannable and useful for navigation

            Quality Standards:
            Prioritize accuracy and usefulness over speed. Each chapter should represent a meaningful content segment that viewers would actually want to jump to directly.
            """
            // swiftlint:enable all
            if !isFirstChunk {
                let additionalInstructions = """

                This is a continuation, the chapters so far are:

                \(chapters.map(\.description).joined(separator: "\n"))

                Do not repeat them, simply continue where they stopped.
                """
                instructions += additionalInstructions
            }

            let prompt = """
            # Video title
            '\(videoTitle)'

            # Transcript
            \(transcriptRepresentation)
            """
            Log.info("prompt \(prompt)")
            let partialChapters = try await getChapters(instructions, prompt, isStart: isFirstChunk)
            chapters.append(contentsOf: partialChapters)
            isFirstChunk = false
        }

        return chapters.map { $0.toSendableChapter }
    }

    private static func getChapters(
        _ instructions: String,
        _ prompt: String,
        isStart: Bool = true
    ) async throws -> [GeneratedChapter] {
        Log.info("instructions \(instructions) \n\nprompt \(prompt)")
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt, generating: ChapterGeneration.self)
        var chapters = response.content.chapters

        if !chapters.isEmpty && isStart {
            // first chapter should always start at 0
            chapters[0].startTime = 0
        }
        return chapters
    }
}

// swiftlint:disable all
@available(iOS 26.0, macOS 26.0, *)
#Playground {
    let transcriptUrl = "https://www.youtube.com/api/timedtext?v=5e2CQ1RknaA&ei=R7PCaMOpC9746dsP06ehkQI&caps=asr&opi=112496729&xoaf=4&hl=en&ip=0.0.0.0&ipbits=0&expire=1757615543&sparams=ip,ipbits,expire,v,ei,caps,opi,xoaf&signature=A669B5833AC344AA82FCA68BDA075ACDA5536334.5E69237930330880C165DA80C950E19C09DE2D27&key=yt8&kind=asr&lang=en"

    let transript = try await TranscriptService.getTranscript(from: transcriptUrl, youtubeId: "5e2CQ1RknaA")

    guard let generatedChapters = try await GenerationService.extractChaptersFromTranscripts(
        "videoTitle",
        transript
    ) else {
        return
    }
    for chapter in generatedChapters {
        print("\(chapter.startTime) - \(chapter.title ?? "-")")
    }
}
// swiftlint:enable all
