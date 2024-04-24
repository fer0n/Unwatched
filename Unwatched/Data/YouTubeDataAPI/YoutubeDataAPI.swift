import Foundation
import OSLog

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
            Logger.log.error("\(error)")
        }
        do {
            return try await YoutubeDataAPI.getYtChannelIdViaList(handle)
        } catch {
            Logger.log.error("\(error)")
        }
        throw SubscriptionError.failedGettingChannelIdFromUsername(lemnosLifeError?.localizedDescription)
    }

    static func getChannelIdViaLemnoslife(from handle: String) async throws -> String {
        Logger.log.info("getLemnoslifeChannelId")
        let url = "https://yt.lemnoslife.com/channels?handle=@\(handle)"
        let subscriptionInfo = try await YoutubeDataAPI.handleYoutubeRequest(url: url, model: YtChannelId.self)
        if let item = subscriptionInfo.items.first {
            return item.id
        }
        throw SubscriptionError.failedGettingChannelIdFromUsername("getChannelIdViaLemnoslife")
    }

    private static func getYtChannelIdViaList(_ handle: String) async throws -> String {
        Logger.log.info("getYtChannelIdViaList")
        let apiUrl = "\(baseUrl)channels?key=\(apiKey)&forHandle=\(handle)&part=id"
        Logger.log.info("apiUrl \(apiUrl)")

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
        Logger.log.info("getYtVideoInfo")
        let apiUrl = "\(baseUrl)videos?key=\(apiKey)&id=\(youtubeVideoId)&part=snippet,contentDetails"
        Logger.log.info("apiUrl \(apiUrl)")

        let response = try await YoutubeDataAPI.handleYoutubeRequest(url: apiUrl, model: YtVideoInfo.self)
        if let item = response.items.first {
            return YoutubeDataAPI.createVideo(
                item.snippet,
                videoId: youtubeVideoId,
                duration: item.contentDetails.duration
            )
        } else if response.items.count == 0 {
            // request seems okay, youtubeVideoId was probably the issue
            throw VideoError.faultyYoutubeVideoId(youtubeVideoId)
        }

        throw VideoError.noVideoFound
    }

    static func createVideo(_ snippet: YtVideoSnippet, videoId: String, duration: String? = nil) -> SendableVideo {
        let dateFormatter = ISO8601DateFormatter()
        let publishedDate = dateFormatter.date(from: snippet.publishedAt)
        let parsedDuration = {
            if let duration = duration {
                return parseDurationToSeconds(duration)
            }
            return nil
        }()
        return SendableVideo(
            youtubeId: videoId,
            title: snippet.title,
            url: URL(string: "https://www.youtube.com/watch?v=\(videoId)")!,
            thumbnailUrl: URL(string: snippet.thumbnails.medium.url),
            youtubeChannelId: snippet.channelId,
            feedTitle: snippet.channelTitle,
            duration: parsedDuration,
            publishedDate: publishedDate,
            videoDescription: snippet.description)
    }

    static func getYtVideoInfoFromPlaylist(_ youtubePlaylistId: String) async throws -> [SendableVideo] {
        if youtubePlaylistId.isEmpty {
            throw VideoError.noYoutubePlaylistId
        }
        Logger.log.info("getYtVideoInfoFromPlaylist")
        let apiUrl = "\(baseUrl)playlistItems?key=\(apiKey)&playlistId=\(youtubePlaylistId)"
            + "&maxResults=50&part=snippet,contentDetails"
        Logger.log.info("apiUrl \(apiUrl)")

        let response = try await YoutubeDataAPI.handleYoutubeRequest(url: apiUrl, model: YtPlaylistItems.self)
        if response.items.isEmpty {
            throw VideoError.noVideosFoundInPlaylist
        }
        var result = [SendableVideo]()
        for item in response.items {
            let video = YoutubeDataAPI.createVideo(item.snippet, videoId: item.contentDetails.videoId)
            result.append(video)
        }
        return result
    }
}
