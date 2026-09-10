//
//  WatchQueueRow.swift
//  UnwatchedWatch
//

import SwiftUI
import UnwatchedShared

/// One line of the queue, from a stored video or from what the phone says it is playing.
struct WatchQueueRow: View {
    private let title: String
    private let channel: String?
    private let artworkUrl: URL?
    private let isSquare: Bool
    private let trailingSymbol: String?

    init(video: Video, isCurrent: Bool) {
        title = video.title
        channel = video.subscription?.title
        artworkUrl = video.displayThumbnailUrl
        isSquare = video.isAudioOnly == true
        trailingSymbol = isCurrent ? Self.playingSymbol : nil
    }

    init(remote: WatchRemoteState) {
        title = remote.title ?? ""
        channel = remote.channelTitle
        artworkUrl = remote.thumbnailUrl
        isSquare = remote.isAudioOnly
        trailingSymbol = remote.isPlaying ? Self.playingSymbol : "iphone"
    }

    var body: some View {
        HStack(spacing: 8) {
            Color.gray.opacity(0.3)
                .overlay {
                    ArtworkFill(url: artworkUrl, isSquare: isSquare, maxPixelSize: Self.side * 3)
                }
                .frame(width: Self.side, height: Self.side)
                .clipShape(.rect(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .lineLimit(2)
                if let channel {
                    Text(channel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let trailingSymbol {
                Image(systemName: trailingSymbol)
                    .font(.caption2)
                    .foregroundStyle(.tint)
            }
        }
    }

    private static let playingSymbol = "speaker.wave.2.fill"
    private static let side: CGFloat = 44
}
