//
//  DescriptionDetailView.swift
//  Unwatched
//

import SwiftUI

struct DescriptionDetailView: View {
    var video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(verbatim: video.title)
                .font(.system(.title2))
                .fontWeight(.bold)
            VStack(alignment: .leading) {
                if let subTitle = video.subscription?.title {
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
        .padding(.horizontal)
        .tint(.teal)
    }
}

#Preview {
    DescriptionDetailView(video: Video.getDummy())
}
