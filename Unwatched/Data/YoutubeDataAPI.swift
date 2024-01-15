import Foundation

class YoutubeDataAPI {
    static var apiKey: String {
        let apiKey = Credentials.apiKey
        guard let apiKey = apiKey else {
            fatalError("youtube-api-key environment varible not set")
        }
        return apiKey
    }

    static let baseUrl = "https://www.googleapis.com/youtube/v3/"

    static func getYtChannelId(from userName: String) async throws -> String {
        do {
            return try await YoutubeDataAPI.getChannelIdViaLemnoslife(from: userName)
        } catch {
            print("\(error)")
        }
        do {
            return try await YoutubeDataAPI.getYtChannelIdViaList(userName)
        } catch {
            print("\(error)")
        }
        throw SubscriptionError.failedGettingChannelIdFromUsername
        // return try await YoutubeDataAPI.getYtChannelIdViaSearch(from: userName)
    }

    static func getChannelIdViaLemnoslife(from handle: String) async throws -> String {
        print("getLemnoslifeChannelId")
        let url = "https://yt.lemnoslife.com/channels?handle=@\(handle)"
        let channelInfo = try await YoutubeDataAPI.handleYoutubeRequest(url: url, model: ChannelId.self)
        if let item = channelInfo.items.first {
            return item.id
        }
        throw SubscriptionError.failedGettingChannelIdFromUsername
    }

    private static func getYtChannelIdViaList(_ username: String) async throws -> String {
        print("getYtChannelIdViaList")
        let apiUrl = "\(baseUrl)channels?key=\(apiKey)&forUsername=\(username)&part=id"
        print("apiUrl", apiUrl)

        let response = try await YoutubeDataAPI.handleYoutubeRequest(url: apiUrl, model: ChannelId.self)
        if let item = response.items.first {
            return item.id
        }

        throw SubscriptionError.failedGettingChannelIdFromUsername
    }

    static func getYtChannelIdViaSearch(from userName: String) async throws -> String {
        print("getYtChannelIdViaSearch")
        let apiUrl = "\(baseUrl)search?key=\(apiKey)&q=\(userName)&type=channel&part=id,snippet"
        print("apiUrl", apiUrl)
        let channelInfo = try await YoutubeDataAPI.handleYoutubeRequest(url: apiUrl, model: ChannelInfo.self)
        if let item = channelInfo.items.first {
            return item.id.channelId
        }

        throw SubscriptionError.failedGettingChannelIdFromUsername
    }

    private static func handleYoutubeRequest<T>(url: String, model: T.Type) async throws -> T where T: Decodable {
        guard let url = URL(string: url) else {
            throw SubscriptionError.notAnUrl(url)
        }
        let (data, urlResponse) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        if let httpResponse = urlResponse as? HTTPURLResponse {
            if let responseBody = String(data: data, encoding: .utf8) {
                print("Response body: \(responseBody)")
            }
            if httpResponse.statusCode != 200 {
                let response = try decoder.decode(ResponseBody.self, from: data)
                throw SubscriptionError.httpRequestFailed(response.error.message)
            }
        }
        return try decoder.decode(T.self, from: data)
    }

    static func getYtVideoInfo(_ youtubeVideoId: String) async throws -> SendableVideo? {
        let apiUrl = "\(baseUrl)videos?key=\(apiKey)&id=\(youtubeVideoId)&part=snippet,contentDetails"
        print("getYtVideoInfo")
        print("apiUrl", apiUrl)

        if let url = URL(string: apiUrl) {
            let (data, _) = try await URLSession.shared.data(from: url)
            print("data", data)
            do {
                let decoder = JSONDecoder()
                let videoInfo = try decoder.decode(VideoInfo.self, from: data)
                if let item = videoInfo.items.first {
                    let dateFormatter = ISO8601DateFormatter()
                    let publishedDate = dateFormatter.date(from: item.snippet.publishedAt)
                    let duration = parseDurationToSeconds(item.contentDetails.duration)
                    return SendableVideo(
                        youtubeId: youtubeVideoId,
                        title: item.snippet.title,
                        url: URL(string: "https://www.youtube.com/watch?v=\(youtubeVideoId)")!,
                        thumbnailUrl: URL(string: item.snippet.thumbnails.medium.url),
                        youtubeChannelId: item.snippet.channelId,
                        feedTitle: item.snippet.channelTitle,
                        duration: duration,
                        publishedDate: publishedDate,
                        status: nil,
                        videoDescription: item.snippet.description)
                }
            } catch {
                print("Error parsing JSON:", error)
            }
        }
        return nil
    }

}

func parseDurationToSeconds(_ duration: String) -> Double? {
    // Check if the string starts with "PT" and ends with "S"
    guard duration.hasPrefix("PT"), duration.hasSuffix("S") else {
        return nil
    }

    // Remove "PT" and "S" from the string
    var durationString = duration.replacingOccurrences(of: "PT", with: "")

    var totalSeconds: Double = 0

    // Extract minutes if present
    if let minuteRange = durationString.range(of: "M") {
        if let minutes = Double(durationString[..<minuteRange.lowerBound]) {
            print("minutes", minutes)
            totalSeconds += minutes * 60
            durationString.removeSubrange(..<minuteRange.upperBound)
        }
    }

    // Extract seconds if present
    if let secondRange = durationString.range(of: "S") {
        if let seconds = Double(durationString[..<secondRange.lowerBound]) {
            print("seconds", seconds)
            totalSeconds += seconds
        }
    }

    return totalSeconds
}

// MARK: - VideoInfo
struct VideoInfo: Codable {
    struct Medium: Codable {
        let url: String
    }

    struct Thumbnails: Codable {
        let medium: Medium
    }

    struct Snippet: Codable {
        let title: String
        let thumbnails: Thumbnails
        let channelTitle: String
        let channelId: String
        let publishedAt: String
        let description: String
    }

    struct ContentDetails: Codable {
        let duration: String
    }

    struct Item: Codable {
        let snippet: Snippet
        let contentDetails: ContentDetails
    }

    let items: [Item]
}

// MARK: - ChannelInfo
struct ChannelInfo: Decodable {

    struct Id: Decodable {
        let channelId: String
    }

    struct Items: Decodable {
        let id: Id
    }

    let items: [Items]
}

// MARK: - ChannelId
struct ChannelId: Decodable {
    struct Item: Decodable {
        var id: String
    }

    var items: [Item]
}

// {
//    "kind": "youtube#channelListResponse",
//    "etag": "dzonrJ8Le3tnzwwHh4tGNofFfs4",
//    "pageInfo": {
//        "totalResults": 1,
//        "resultsPerPage": 5
//    },
//    "items": [
//        {
//            "kind": "youtube#channel",
//            "etag": "ZD6Vr3iThVcmOSqcf1lJfOeWHf8",
//            "id": "UC-ImLFXGIe2FC4Wo5hOodnw"
//        }
//    ]
// }

// MARK: - error response body
struct ResponseBody: Decodable {
    struct Error: Decodable {
        var code: Int
        var message: String
    }
    var error: Error
}
