//
//  GenerationService.swift
//  Unwatched
//

import FoundationModels
import UnwatchedShared
import Playgrounds

@available(iOS 26.0, macOS 26.0, *)
struct GenerationService {
    static let characterLimit = 7000 // 4096 token limit * roughly 4 characters per token

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
            Break the transcript into a few broad, well-sized sections (based on the timestamps in seconds). Each section should reflect a natural break or shift in topic, pacing, or structure. Use short, general-purpose titles — not detailed summaries. Avoid combining unrelated topics or making the chapters too short.
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
    let transcriptUrl = "https://www.youtube.com/api/timedtext?v=JUG1PlqAUJk&ei=0u6gaI2CBaLnxN8Pw__cSQ&caps=asr&opi=112496729&xoaf=5&xospf=1&hl=en&ip=0.0.0.0&ipbits=0&expire=1755402562&sparams=ip,ipbits,expire,v,ei,caps,opi,xoaf&signature=54ADDF3B0429D37E727CDE8DB462A03E47D51B25.784B8086812A945E32E192A61F3FE287244FE385&key=yt8&kind=asr&lang=en&variant=punctuated"

    let transript = try await TranscriptService.getTranscript(from: transcriptUrl, youtubeId: "youtubeId")

    let generatedChapters = try await GenerationService.extractChaptersFromTranscripts(
        "videoTitle",
        transript
    )
    print("generatedChapters", generatedChapters)
}
// swiftlint:enable all
