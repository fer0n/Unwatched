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

    static func getYtChannelIdFromUsername(username: String) async throws -> String {
        let apiUrl = "\(baseUrl)channels?key=\(apiKey)&forUsername=\(username)&part=id"
        print("apiUrl", apiUrl)

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

                    return SendableVideo(
                        youtubeId: youtubeVideoId,
                        title: item.snippet.title,
                        url: URL(string: "https://www.youtube.com/watch?v=\(youtubeVideoId)")!,
                        thumbnailUrl: URL(string: item.snippet.thumbnails.medium.url),
                        youtubeChannelId: item.snippet.channelId,
                        feedTitle: item.snippet.channelTitle,
                        duration: item.contentDetails.duration,
                        publishedDate: publishedDate,
                        status: nil)
                }
            } catch {
                print("Error parsing JSON:", error)
            }
        }
        return nil
    }

}

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
}

struct ContentDetails: Codable {
    let duration: String
}

struct Item: Codable {
    let snippet: Snippet
    let contentDetails: ContentDetails
}

struct VideoInfo: Codable {
    let items: [Item]
}
