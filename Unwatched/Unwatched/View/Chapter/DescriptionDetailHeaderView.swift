//
//  DescriptionDetailHeaderView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DescriptionDetailHeaderView: View {
    @State var hapticToggle = false
    @ScaledMetric var subTitleSize: CGFloat = 15

    let video: Video
    let onTitleTap: () -> Void

    var body: some View {
        Button {
            onTitleTap()
        } label: {
            Text(verbatim: video.title)
                .font(.title)
                .fontWeight(.semibold)
                .fontWidth(.compressed)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.roundedRectangle(radius: 10))
        .contextMenu {
            CopyUrlOptions(asSection: true, video: video, onSuccess: {
                hapticToggle.toggle()
            })
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)

        VStack(alignment: .leading) {
            InteractiveSubscriptionTitle(
                subscription: video.subscription
            )
            .equatable()
            if let published = video.publishedDate {
                Text(verbatim: "\(published.formattedExtensive) (\(publishedDateText(published)))")
                    .accessibilityLabel(published.formatted(.relative(presentation: .named, unitsStyle: .spellOut)))
            }
            if let duration = video.duration {
                Text(verbatim: duration.formattedSeconds)
                    .accessibilityLabel(
                        "\(Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes]))) long"
                    )
            }
        }
        .foregroundStyle(.secondary)
        .font(.system(size: subTitleSize))
        .fontWeight(.regular)
        .accessibilityElement(children: .combine)
    }

    func publishedDateText(_ published: Date) -> String {
        published.formattedRelative
    }
}

#Preview {
    DescriptionDetailView(description: Video.getDummy().description)
}
