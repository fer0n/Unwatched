//
//  CopyUrlMenu.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CopyUrlOptions: View {
    @AppStorage(Const.copyAppUrl) var copyAppUrl: Bool = false

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
        // the rest are YouTube URLs; a podcast episode only has its own page
        if !video.isPodcast {
            copyUrlTimestampButton
            copyPlaylistUrlButton
            Divider()
            copyChannelUrlButton
        }
        Divider()
        appUrlToggle
    }

    var appUrlToggle: some View {
        let toggle = Button {
            copyAppUrl.toggle()
        } label: {
            Text("appUrl")
            Text("appUrlSubtitle")
            Image(systemName: copyAppUrl ? "checkmark.square.fill" : "square")
        }
        .accessibilityAddTraits(copyAppUrl ? .isSelected : [])
        #if os(macOS)
        return toggle
        #else
        return toggle.menuActionDismissBehavior(.disabled)
        #endif
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
            guard let url = UrlService.getShareUrl(video) else { return }
            copyUrl(url, "video")
        } label: {
            Label("video", systemImage: "play.rectangle.fill")
                .fontWeight(.black)
        }
    }

    @ViewBuilder
    var copyUrlTimestampButton: some View {
        if let getTimestamp {
            Button {
                guard let url = UrlService.getShareUrl(video, timestamp: getTimestamp()) else { return }
                copyUrl(url, "timestamp")
            } label: {
                Text("videoAtTimestamp")
            }
        }
    }

    func copyUrl(_ url: String, _ option: String) {
        ClipboardService.set(url)
        Signal.interaction("Player.MoreMenu", "copyUrl", parameters: ["option": option])
        onSuccess?()
    }
}
