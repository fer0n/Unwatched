//
//  DescriptionDetailView.swift
//  Unwatched
//

import SwiftUI

struct DescriptionDetailView: View {
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme

    var video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(verbatim: video.title)
                .font(.system(.title2))
                .fontWeight(.bold)
            VStack(alignment: .leading) {
                if let subTitle = video.subscription?.displayTitle {
                    Text(verbatim: subTitle)
                }
                if let published = video.publishedDate {
                    Text(verbatim: "\(published.formatted)")
                }
                if let timeString = video.duration?.formattedSeconds {
                    Text(verbatim: timeString)
                }
            }
            .foregroundStyle(.secondary)
            if let desc = video.videoDescription {
                Text(LocalizedStringKey(desc))
            }
            Spacer()
        }
        .tint(theme.color)
        .padding(.horizontal)
    }
}

#Preview {
    DescriptionDetailView(video: Video.getDummy())
}
