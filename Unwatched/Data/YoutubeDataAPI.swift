import Foundation

class YoutubeDataAPI {
    static var apiKey: String {
        let apiKey = ProcessInfo.processInfo.environment["youtube-api-key"]
        guard let apiKey = apiKey else {
            fatalError("youtube-api-key environment varible not set")
        }
        return apiKey
    }

    static let baseUrl = "https://www.googleapis.com/youtube/v3/"

    static func getYtChannelIdFromUsername(_ username: String) async throws -> String {
        let apiUrl = "\(baseUrl)channels?key=\(apiKey)&forUsername=\(username)&part=id"

        if let url = URL(string: apiUrl) {
            let (data, _) = try await URLSession.shared.data(from: url)
            print("data", data)
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("json", json)
                if let items = json["items"] as? [[String: Any]],
                   let item = items.first,
                   let id = item["id"] as? String {
                    return id
                }
            }
        }
        throw SubscriptionError.failedGettingChannelIdFromUsername
    }

    static func getYtChannelIdViaList(from userName: String) async throws -> String {
        let apiUrl = "\(baseUrl)search?key=\(apiKey)&q=\(userName)&type=channel&part=id,snippet"
        print("apiUrl", apiUrl)

        if let url = URL(string: apiUrl) {
            let (data, _) = try await URLSession.shared.data(from: url)
            print("data", data)
            do {
                let decoder = JSONDecoder()
                let channelInfo = try decoder.decode(ChannelInfo.self, from: data)
                if let item = channelInfo.items.first {
                    return item.id.channelId
                }
            } catch {
                print("Error parsing JSON:", error)
            }
        }
        throw SubscriptionError.failedGettingChannelIdFromUsername
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
