import SwiftUI
import UnwatchedShared

struct ChapterListItem: View {
    var chapter: Chapter
    var toggleChapter: (_ chapter: Chapter) -> Void
    var spacing: CGFloat = 5
    var currentTime: Double?

    @ScaledMetric var frameSize = 30
    @State var toggleHaptic = false

    var body: some View {
        HStack(spacing: spacing) {
            toggleChapterButton
                .opacity(chapter.isActive ? 1 : 0.6)

            VStack(alignment: .leading) {
                if let title = chapter.titleText {
                    Text(title)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                        .accessibilityElement()
                        .accessibilityLabel(title)
                }
                let timeInfo = ChapterTimeInfo(chapter: chapter, currentTime: currentTime)
                if let short = timeInfo.short, let verbose = timeInfo.verbose {
                    Text(short)
                        .font(.subheadline.monospacedDigit())
                        .animation(.default, value: short)
                        .contentTransition(.numericText(countsDown: true))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityElement()
                        .accessibilityLabel(verbose)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(nil, value: chapter.isActive)
            .opacity(chapter.isActive ? 1 : 0.6)

            if let link = chapter.link {
                Link(destination: link, label: {
                    Image(systemName: "link.circle.fill")
                        .resizable()
                        .frame(width: frameSize, height: frameSize)
                })
                .opacity(chapter.isActive ? 1 : 0.6)
            }
        }
    }

    var toggleChapterButton: some View {
        Button {
            toggleChapter(chapter)
            toggleHaptic.toggle()
        } label: {
            ZStack {
                Image(systemName: Const.circleBackgroundSF)
                    .resizable()
                    .frame(width: frameSize, height: frameSize)
                    .foregroundStyle(Color.backgroundColor)

                if chapter.isActive {
                    Image(systemName: Const.checkmarkSF)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.neutralAccentColor)
                }
            }
            .animation(nil, value: chapter.isActive)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(Const.sensoryFeedback, trigger: toggleHaptic)
        .accessibilityElement()
        .accessibilityValue(accessibilityLabelToggle)
        .accessibilityAction {
            toggleChapter(chapter)
            toggleHaptic.toggle()
        }
    }

    var accessibilityLabelToggle: String {
        chapter.isActive ? String(localized: "disable") : String(localized: "enable")
    }

    struct ChapterTimeInfo {
        let short: String?
        let verbose: String?

        init(chapter: Chapter, currentTime: Double?) {
            if let currentTime, let endTime = chapter.endTime {
                let remaining = endTime - currentTime
                self.short = String(localized: "\(remaining.formattedSeconds) remaining")
                self.verbose = String(localized: "\(Duration.seconds(remaining).formatted(.units())) remaining")
            } else if let duration = chapter.duration {
                self.short = duration.formattedSeconds
                self.verbose = Duration.seconds(duration).formatted(.units())
            } else {
                self.short = nil
                self.verbose = nil
            }
        }
    }
}

#Preview {
    VStack {
        ChapterListItem(chapter: Chapter(
            title: "Hello there",
            time: 102
        ), toggleChapter: { _ in },
        currentTime: 10,
        )
        .background(Color.gray)

        ChapterListItem(chapter: Chapter(
            title: nil,
            time: 102
        ), toggleChapter: { _ in },
        currentTime: 10,
        )
        .background(Color.gray)
    }
}

#Preview {
    let texts = [
        "Long long long long long long long long long long text",
        "text",
        "text",
        "text",
        "LAST"
    ]

    ZStack {}
        .popover(isPresented: .constant(true), arrowEdge: .trailing) {
            ForEach(texts, id: \.self) { text in
                Text(text)
                    .multilineTextAlignment(.leading)
                    .frame(idealWidth: 300)
                // .fixedSize(horizontal: false, vertical: true)
            }
            .presentationCompactAdaptation(.popover)
        }
}
