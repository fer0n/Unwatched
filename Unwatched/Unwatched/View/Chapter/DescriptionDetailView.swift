//
//  DescriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DescriptionDetailView: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    var video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let desc = video.videoDescription {
                let texts = desc.split(separator: "\n", omittingEmptySubsequences: false)
                ForEach(texts, id: \.self) { text in
                    Text(LocalizedStringKey(String(text)))
                }
            }
        }
        .textSelection(.enabled)
        .tint(theme.color)
    }
}

struct DescriptionDetailHeaderView: View {
    let video: Video
    let onTitleTap: () -> Void
    let setShowMenu: (() -> Void)?

    var body: some View {
        Button {
            onTitleTap()
        } label: {
            Text(verbatim: video.title)
                .font(.system(.title2))
                .fontWeight(.black)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let url = video.url {
                Button {
                    ClipboardService.set(url.absoluteString)
                } label: {
                    Label("copyUrl", systemImage: "document.on.document.fill")
                }
            }
        }

        VStack(alignment: .leading) {
            InteractiveSubscriptionTitle(
                video: video,
                subscription: video.subscription,
                setShowMenu: setShowMenu
            )
            if let published = video.publishedDate {
                Text(verbatim: "\(published.formattedExtensive)")
            }
            if let timeString = video.duration?.formattedSeconds {
                Text(verbatim: timeString)
            }
        }
        .foregroundStyle(.secondary)
    }
}

#Preview {
    DescriptionDetailView(video: Video.getDummy())
}
