//
//  DescriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DescriptionDetailView: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    var description: String?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if let description {
                let texts = description.split(separator: "\n", omittingEmptySubsequences: false)
                ForEach(Array(texts.enumerated()), id: \.offset) { _, text in
                    Text(LocalizedStringKey(String(text)))
                }
            }
        }
        .textSelection(.enabled)
        .tint(theme.color)
    }
}

struct DescriptionDetailHeaderView: View {
    @State var hapticToggle = false
    @ScaledMetric var titleSize: CGFloat = 35
    @ScaledMetric var subTitleSize: CGFloat = 15

    let video: Video
    var smallTitle = false
    let onTitleTap: () -> Void
    let setShowMenu: (() -> Void)?

    var body: some View {
        Button {
            onTitleTap()
        } label: {
            Text(verbatim: video.title)
                .font(smallTitle
                        ? .title
                        : .system(size: titleSize))
                .fontWeight(.semibold)
                .fontWidth(.compressed)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .contextMenu {
            CopyUrlOptions(asSection: true, video: video, onSuccess: {
                hapticToggle.toggle()
            })
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)

        VStack(alignment: .leading) {
            InteractiveSubscriptionTitle(
                subscription: video.subscription,
                setShowMenu: setShowMenu
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
