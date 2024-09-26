//
//  SponsorBlockAPI.swift
//  Unwatched
//

import Foundation
import OSLog
import UnwatchedShared

struct SponsorBlockAPI {
    static let baseUrl = "https://sponsor.ajay.app/api/"

    static func skipSegments(for videoID: String, allSegments: Bool) async throws -> [SponsorBlockSegmentModel] {
        let segmentsQuery = allSegments
            ? #"&categories=["sponsor","intro","selfpromo","interaction","outro","preview","music_offtopic","filler"]"#
            : ""
        let urlString = baseUrl + "skipSegments?videoID=\(videoID)" + segmentsQuery
        guard let url = URL(string: urlString) else {
            throw SponsorBlockError.noValidUrl
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        print("skipSegments url: \(urlString)")
        if let result = try? decoder.decode([SponsorBlockSegmentModel].self, from: data) {
            return result
        } else {
            let jsonString = String(decoding: data, as: UTF8.self)
            throw SponsorBlockError.httpRequestFailed(jsonString)
        }
    }

    static func getChapters(from segments: [SponsorBlockSegmentModel]) -> [SendableChapter] {
        var result = [SendableChapter]()
        for segment in segments {
            guard let startTime = segment.segment.first else {
                Logger.log.warning("Start time for sponsored segment could not be found")
                continue
            }
            let endTime = segment.segment.last

            let category = ChapterCategory.parse(segment.category)

            let chapter = SendableChapter(
                title: nil,
                startTime: startTime,
                endTime: endTime,
                category: category
            )
            result.append(chapter)
        }
        return result
    }
}

struct SponsorBlockSegmentModel: Codable {
    var category: String
    var actionType: String
    var segment: [Double]
    var UUID: String
    var videoDuration: Double
    var locked: Int
    var votes: Int
    var description: String
}

enum SponsorBlockError: Error {
    case httpRequestFailed(String)
    case noValidUrl
}
