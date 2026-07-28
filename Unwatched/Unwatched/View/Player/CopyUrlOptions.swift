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
                Image(systemName: Const.shareSF)
            }
        }
    }

    @ViewBuilder
    var options: some View {
        copyUrlButton
        copyUrlTimestampButton
        copyPlaylistUrlButton
        Divider()
        copyChannelUrlButton
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
                Label("channel", systemImage: "person.fill")
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
    var copyUrlButton: some View {
        Button {
            let text = UrlService.getShortenedUrl(video.youtubeId)
            copyUrl(text, "video")
        } label: {
            Label("video", systemImage: "play.rectangle.fill")
                .fontWeight(.black)
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
