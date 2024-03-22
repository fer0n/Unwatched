import Foundation

struct YoutubeDataAPI {
    static var apiKey: String {
        let apiKey = Credentials.apiKey
        guard let apiKey = apiKey else {
            fatalError("youtube-api-key environment varible not set")
        }
        return apiKey
    }

    static let baseUrl = "https://www.googleapis.com/youtube/v3/"

    static func getYtChannelId(from handle: String) async throws -> String {
        var lemnosLifeError: Error?
        do {
            return try await YoutubeDataAPI.getChannelIdViaLemnoslife(from: handle)
        } catch {
            lemnosLifeError = error
            print("\(error)")
        }
        do {
            return try await YoutubeDataAPI.getYtChannelIdViaList(handle)
        } catch {
            print("\(error)")
        }
        throw SubscriptionError.failedGettingChannelIdFromUsername(lemnosLifeError?.localizedDescription)
    }

    static func getChannelIdViaLemnoslife(from handle: String) async throws -> String {
        print("getLemnoslifeChannelId")
        let url = "https://yt.lemnoslife.com/channels?handle=@\(handle)"
        let channelInfo = try await YoutubeDataAPI.handleYoutubeRequest(url: url, model: YtChannelId.self)
        if let item = channelInfo.items.first {
            return item.id
        }
        throw SubscriptionError.failedGettingChannelIdFromUsername("getChannelIdViaLemnoslife")
    }

    private static func getYtChannelIdViaList(_ handle: String) async throws -> String {
        print("getYtChannelIdViaList")
        let apiUrl = "\(baseUrl)channels?key=\(apiKey)&forHandle=\(handle)&part=id"
        print("apiUrl \(apiUrl)")

        let response = try await YoutubeDataAPI.handleYoutubeRequest(url: apiUrl, model: YtChannelId.self)
        if let item = response.items.first {
            return item.id
        }

        throw SubscriptionError.failedGettingChannelIdFromUsername("getYtChannelIdViaList")
    }

    private static func handleYoutubeRequest<T>(url: String, model: T.Type) async throws -> T where T: Decodable {
        guard let url = URL(string: url) else {
            throw SubscriptionError.notAnUrl(url)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()

        if let result = try? decoder.decode(T.self, from: data) {
            return result
        } else {
            let response = try decoder.decode(YtErrorResponseBody.self, from: data)
            throw SubscriptionError.httpRequestFailed(response.error.message)
        }
    }

    static func getYtVideoInfo(_ youtubeVideoId: String) async throws -> SendableVideo? {
        if youtubeVideoId.isEmpty {
            throw VideoError.noYoutubeId
        }
        print("getYtVideoInfo")
        let apiUrl = "\(baseUrl)videos?key=\(apiKey)&id=\(youtubeVideoId)&part=snippet,contentDetails"
        print("apiUrl \(apiUrl)")

        let response = try await YoutubeDataAPI.handleYoutubeRequest(url: apiUrl, model: YtVideoInfo.self)
        if let item = response.items.first {
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
                videoDescription: item.snippet.description)
        } else if response.items.count == 0 {
            // request seems okay, youtubeVideoId was probably the issue
            throw VideoError.faultyYoutubeVideoId(youtubeVideoId)
        }

        throw VideoError.noVideoFound
    }
}
