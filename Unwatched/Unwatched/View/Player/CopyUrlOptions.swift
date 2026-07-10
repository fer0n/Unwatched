//
//  CopyUrlMenu.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CopyUrlOptions: View {
    var asSection: Bool = false
    var video: Video
    var getTimestamp: (() -> Double)?
    var onSuccess: (() -> Void)?

    var body: some View {
        if asSection {
            Section("copyUrl") {
                options
            }
        } else {
            Menu {
                options
            } label: {
                Text("copyUrl")
                Image(systemName: Const.copySF)
            }
        }
    }

    @ViewBuilder
    var options: some View {
        copyUrlButton
        copyUrlTimestampButton
        copyPlaylistUrlButton
        copyChannelUrlButton
        copyRssFeedUrlButton
    }

    @ViewBuilder
    var copyChannelUrlButton: some View {
        if video.subscription != nil {
            Button {
                if let channel = video.subscription,
                   let urlString = UrlService.getYoutubeUrl(
                    userName: channel.youtubeUserName,
                    channelId: channel.youtubeChannelId,
                    mobile: false,
                    videosSubPath: false) {
                    copyUrl(urlString, "channel")
                }
            } label: {
                Text("channel")
            }
        }
    }

    @ViewBuilder
    var copyPlaylistUrlButton: some View {
        if let playlistId = video.subscription?.youtubePlaylistId {
            Button {
                if let urlString = UrlService.getYoutubeUrl(
                    playlistId: playlistId,
                    mobile: false
                ) {
                    copyUrl(urlString, "playlist")
                }
            } label: {
                Text("playlist")
            }
        }
    }

    @ViewBuilder
    var copyRssFeedUrlButton: some View {
        if let urlString = video.subscription?.link?.absoluteString {
            Button {
                copyUrl(urlString, "rssFeed")
            } label: {
                Text("rssFeed")
            }
        }
    }

    @ViewBuilder
    var copyUrlButton: some View {
        Button {
            let text = UrlService.getShortenedUrl(video.youtubeId)
            copyUrl(text, "video")
        } label: {
            Text("video")
        }
    }

    @ViewBuilder
    var copyUrlTimestampButton: some View {
        if let getTimestamp {
            Button {
                let text = UrlService.getShortenedUrl(
                    video.youtubeId,
                    timestamp: getTimestamp()
                )
                copyUrl(text, "timestamp")
            } label: {
                Text("videoAtTimestamp")
            }
        }
    }

    func copyUrl(_ url: String, _ option: String) {
        ClipboardService.set(url)
        Signal.log("Player.MoreMenu", parameters: ["action": "copyUrl", "option": option])
        onSuccess?()
    }
}
