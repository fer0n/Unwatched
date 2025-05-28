import Foundation
import OSLog
import UnwatchedShared

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
        Log.info("getYtChannelId")
        let apiUrl = "\(baseUrl)channels?key=\(apiKey)&forHandle=\(handle)&part=id"

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

        do {
            let result = try decoder.decode(T.self, from: data)
            return result
        } catch {
            Log.info("couldn't decode result: \(error)")
        }

        let response = try decoder.decode(YtErrorResponseBody.self, from: data)
        throw SubscriptionError.httpRequestFailed(response.error.message)

    }

    static func getYtVideoInfo(_ youtubeVideoId: String) async throws -> SendableVideo? {
        if youtubeVideoId.isEmpty {
            throw VideoError.noYoutubeId
        }
        Log.info("getYtVideoInfo")
        let apiUrl = "\(baseUrl)videos?key=\(apiKey)&id=\(youtubeVideoId)&part=snippet,contentDetails"

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
        let publishedDate = try? Date(snippet.publishedAt, strategy: .iso8601)
        let parsedDuration = {
            if let duration = duration {
                return parseDurationToSeconds(duration)
            }
            return nil
        }()
        let url: URL? = {
            if let stringUrl = snippet.thumbnails.medium?.url {
                return URL(string: stringUrl)
            }
            return nil
        }()

        return SendableVideo(
            youtubeId: videoId,
            title: snippet.title,
            url: URL(string: "https://www.youtube.com/watch?v=\(videoId)")!,
            thumbnailUrl: url,
            youtubeChannelId: snippet.channelId,
            feedTitle: snippet.channelTitle,
            duration: parsedDuration,
            publishedDate: publishedDate,
            videoDescription: snippet.description)
    }

    static func getYtPlaylistUrl(_ youtubePlaylistId: String, _ pageToken: String?) -> String {
        let pageTokenString = pageToken?.isEmpty == false ? "&pageToken=\(pageToken!)" : ""

        return "\(baseUrl)playlistItems?key=\(apiKey)&playlistId=\(youtubePlaylistId)"
            + "&maxResults=50&part=snippet,contentDetails\(pageTokenString)"
    }

    static func getYtVideoInfoFromPlaylist(_ youtubePlaylistId: String) async throws -> [SendableVideo] {
        if youtubePlaylistId.isEmpty {
            throw VideoError.noYoutubePlaylistId
        }
        Log.info("getYtVideoInfoFromPlaylist")

        var result = [SendableVideo]()
        var nextPageToken: String?
        var counter = 0

        repeat {
            let apiUrl = getYtPlaylistUrl(youtubePlaylistId, nextPageToken)
            counter += 1
            let response = try await YoutubeDataAPI.handleYoutubeRequest(url: apiUrl, model: YtPlaylistItems.self)
            if response.items.isEmpty {
                throw VideoError.noVideosFoundInPlaylist
            }
            for item in response.items {
                let video = YoutubeDataAPI.createVideo(item.snippet, videoId: item.contentDetails.videoId)
                result.append(video)
            }
            Log.info("getYtVideoInfoFromPlaylist: \(result.count), \(response.pageInfo.resultsPerPage), \(response.pageInfo.totalResults)")
            nextPageToken = response.nextPageToken
        } while nextPageToken != nil && counter < Const.playlistPageRequestLimit

        Log.info("Amount of imported videos: \(result.count)")
        return result
    }
}
