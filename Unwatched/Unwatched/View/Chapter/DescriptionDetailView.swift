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
        VStack(alignment: .leading, spacing: 15) {
            Text(verbatim: video.title)
                .font(.system(.title2))
                .fontWeight(.black)
            VStack(alignment: .leading) {
                if let subTitle = video.subscription?.displayTitle {
                    Text(verbatim: subTitle)
                }
                if let published = video.publishedDate {
                    Text(verbatim: "\(published.formattedExtensive)")
                }
                if let timeString = video.duration?.formattedSeconds {
                    Text(verbatim: timeString)
                }
            }
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                if let desc = video.videoDescription {
                    let texts = desc.split(separator: "\n", omittingEmptySubsequences: false)
                    ForEach(texts, id: \.self) { text in
                        Text(LocalizedStringKey(String(text)))
                    }
                }
            }
            Spacer()
        }
        .textSelection(.enabled)
        .tint(theme.color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

#Preview {
    DescriptionDetailView(video: Video.getDummy())
}
